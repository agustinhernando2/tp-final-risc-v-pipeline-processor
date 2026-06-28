#!/usr/bin/env python3
"""GUI gráfica de depuración del procesador RISC-V vía UART.

Ventana de escritorio (Tkinter) que junta las tres piezas del lado-host:

  - editor de assembly + ensamblador (`assembler.py`) para compilar en el momento;
  - capa de protocolo UART (`uart.py`) para cargar y ejecutar en la placa;
  - vistas de código máquina, banco de registros, memoria de datos y PC.

Flujo típico:  abrir/escribir asm -> Compilar -> Conectar -> Enviar programa ->
Ejecución continua / Step -> leer el volcado de estado.

Pensada como complemento de `riscv_debug.py` (la CLI): misma capa `uart.py`, pero
con una interfaz visual. Compilar funciona sin placa (útil para validar offline).

Ejecutar:  uv run gui.py     (o  python3 gui.py  con pyserial instalado)
"""

import glob
import os
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import assembler
import uart

try:
    from serial.tools import list_ports
except ImportError:  # pyserial no instalado: la GUI igual compila offline
    list_ports = None

PROGRAMS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "programs")
BAUD_RATES = ["9600", "19200", "38400", "57600", "115200"]
MONO = ("Courier New", 10)


class LineNumbers(tk.Canvas):
    """Pequeño gutter con números de línea, sincronizado con un Text."""

    def __init__(self, master, text_widget, **kw):
        super().__init__(master, width=40, bg="#f0f0f0", highlightthickness=0, **kw)
        self.text = text_widget

    def redraw(self, *_):
        self.delete("all")
        i = self.text.index("@0,0")
        while True:
            dline = self.text.dlineinfo(i)
            if dline is None:
                break
            self.create_text(38, dline[1], anchor="ne", font=MONO,
                             fill="#888", text=i.split(".")[0])
            i = self.text.index(f"{i}+1line")


class DebugGui(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("RISC-V Debug GUI")
        self.geometry("1100x780")
        self.minsize(900, 640)

        self.uart = None            # instancia uart.Uart cuando hay conexión
        self.in_step_mode = False   # ya entramos en modo paso a paso?
        self.words = []             # último programa compilado

        self._build_connection_bar()
        self._build_main_panels()
        self._build_buttons()
        self._build_log()
        self.refresh_ports()
        self._update_button_states()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # --- Construcción de la UI ------------------------------------------------
    def _build_connection_bar(self):
        bar = ttk.Frame(self, padding=6)
        bar.pack(fill="x")
        ttk.Label(bar, text="Puerto:").pack(side="left")
        self.port_cb = ttk.Combobox(bar, width=22, state="readonly")
        self.port_cb.pack(side="left", padx=4)
        ttk.Button(bar, text="↻", width=3, command=self.refresh_ports).pack(side="left")
        ttk.Label(bar, text="Baud:").pack(side="left", padx=(12, 0))
        self.baud_cb = ttk.Combobox(bar, width=8, state="readonly", values=BAUD_RATES)
        self.baud_cb.set("19200")
        self.baud_cb.pack(side="left", padx=4)
        self.connect_btn = ttk.Button(bar, text="Conectar", command=self.toggle_connection)
        self.connect_btn.pack(side="left", padx=12)
        self.status_lbl = ttk.Label(bar, text="● desconectado", foreground="#b00")
        self.status_lbl.pack(side="left")

    def _build_main_panels(self):
        # Panel superior: editor (izq) | código máquina (der)
        top = ttk.Panedwindow(self, orient="horizontal")
        top.pack(fill="both", expand=True, padx=6)

        left = ttk.Labelframe(top, text="Código assembly", padding=4)
        toolbar = ttk.Frame(left)
        toolbar.pack(fill="x")
        ttk.Button(toolbar, text="Abrir…", command=self.open_file).pack(side="left")
        ttk.Button(toolbar, text="Guardar…", command=self.save_file).pack(side="left", padx=4)
        ttk.Label(toolbar, text="Ejemplos:").pack(side="left", padx=(12, 2))
        self.example_cb = ttk.Combobox(toolbar, width=20, state="readonly")
        self.example_cb.pack(side="left")
        self.example_cb.bind("<<ComboboxSelected>>", self.load_example)
        self._populate_examples()

        editor_frame = ttk.Frame(left)
        editor_frame.pack(fill="both", expand=True, pady=(4, 0))
        self.editor = tk.Text(editor_frame, wrap="none", font=MONO, undo=True)
        self.gutter = LineNumbers(editor_frame, self.editor)
        yscroll = ttk.Scrollbar(editor_frame, command=self._on_editor_scroll)
        self.editor.configure(yscrollcommand=self._on_editor_yview)
        self.gutter.pack(side="left", fill="y")
        yscroll.pack(side="right", fill="y")
        self.editor.pack(side="left", fill="both", expand=True)
        self._editor_scrollbar = yscroll
        self.editor.bind("<KeyRelease>", self.gutter.redraw)
        self.editor.bind("<Configure>", self.gutter.redraw)
        top.add(left, weight=3)

        right = ttk.Labelframe(top, text="Código máquina", padding=4)
        self.code_tv = ttk.Treeview(right, columns=("idx", "hex", "bin"),
                                     show="headings", height=10)
        for col, txt, w in (("idx", "#", 40), ("hex", "hex", 90), ("bin", "binario", 280)):
            self.code_tv.heading(col, text=txt)
            self.code_tv.column(col, width=w, anchor="w")
        self.code_tv.pack(fill="both", expand=True)
        top.add(right, weight=2)

        # Panel inferior: registros | memoria | PC
        bottom = ttk.Frame(self, padding=(6, 4))
        bottom.pack(fill="both", expand=True)
        self.reg_tv = self._make_table(bottom, "Banco de registros",
                                       ("reg", "hex", "dec"), ("reg", "hex", "valor"))
        self.mem_tv = self._make_table(bottom, "Memoria de datos",
                                       ("idx", "hex", "dec"), ("word", "hex", "valor"))
        pc_frame = ttk.Labelframe(bottom, text="PC", padding=8)
        pc_frame.pack(side="left", fill="y", padx=4)
        self.pc_lbl = ttk.Label(pc_frame, text="—", font=("Courier New", 14, "bold"))
        self.pc_lbl.pack()

    def _make_table(self, parent, title, cols, headers):
        frame = ttk.Labelframe(parent, text=title, padding=4)
        frame.pack(side="left", fill="both", expand=True, padx=4)
        tv = ttk.Treeview(frame, columns=cols, show="headings")
        for col, head in zip(cols, headers):
            tv.heading(col, text=head)
            tv.column(col, width=90, anchor="w")
        scroll = ttk.Scrollbar(frame, command=tv.yview)
        tv.configure(yscrollcommand=scroll.set)
        scroll.pack(side="right", fill="y")
        tv.pack(side="left", fill="both", expand=True)
        return tv

    def _build_buttons(self):
        row = ttk.Frame(self, padding=6)
        row.pack(fill="x")
        self.btn_compile = ttk.Button(row, text="Compilar", command=self.compile_source)
        self.btn_load = ttk.Button(row, text="Enviar programa", command=self.send_program)
        self.btn_run = ttk.Button(row, text="Ejecución continua", command=self.run_continuous)
        self.btn_step = ttk.Button(row, text="Step", command=self.run_step)
        self.btn_info = ttk.Button(row, text="Obtener info", command=self.get_info)
        for b in (self.btn_compile, self.btn_load, self.btn_run, self.btn_step, self.btn_info):
            b.pack(side="left", padx=4)

    def _build_log(self):
        frame = ttk.Labelframe(self, text="Log", padding=4)
        frame.pack(fill="x", padx=6, pady=(0, 6))
        self.log_txt = tk.Text(frame, height=6, font=MONO, state="disabled", wrap="word")
        self.log_txt.pack(fill="x")

    # --- Sincronización de scroll editor/gutter -------------------------------
    def _on_editor_yview(self, *args):
        self._editor_scrollbar.set(*args)
        self.gutter.redraw()

    def _on_editor_scroll(self, *args):
        self.editor.yview(*args)
        self.gutter.redraw()

    # --- Utilidades de UI -----------------------------------------------------
    def log(self, msg, error=False):
        self.log_txt.configure(state="normal")
        self.log_txt.insert("end", ("✗ " if error else "• ") + msg + "\n")
        self.log_txt.see("end")
        self.log_txt.configure(state="disabled")

    def _populate_examples(self):
        names = sorted(os.path.basename(p) for p in glob.glob(os.path.join(PROGRAMS_DIR, "*.s")))
        self.example_cb.configure(values=names)

    def _update_button_states(self):
        connected = self.uart is not None
        state = "normal" if connected else "disabled"
        for b in (self.btn_load, self.btn_run, self.btn_step, self.btn_info):
            b.configure(state=state)

    # --- Conexión -------------------------------------------------------------
    def refresh_ports(self):
        ports = []
        if list_ports is not None:
            ports = [p.device for p in list_ports.comports()]
        # Fallback: dispositivos serie típicos en Linux por si list_ports falla.
        ports = ports or sorted(glob.glob("/dev/ttyUSB*") + glob.glob("/dev/ttyACM*"))
        self.port_cb.configure(values=ports)
        if ports and not self.port_cb.get():
            self.port_cb.set(ports[0])

    def toggle_connection(self):
        if self.uart is not None:
            self.uart.close()
            self.uart = None
            self.in_step_mode = False
            self.status_lbl.configure(text="● desconectado", foreground="#b00")
            self.connect_btn.configure(text="Conectar")
            self.log("Desconectado.")
        else:
            port = self.port_cb.get()
            if not port:
                self.log("No hay puerto seleccionado.", error=True)
                return
            try:
                self.uart = uart.Uart(port, int(self.baud_cb.get()))
            except Exception as e:  # noqa: BLE001 (queremos reportar cualquier error serie)
                self.log(f"No se pudo abrir {port}: {e}", error=True)
                return
            self.status_lbl.configure(text=f"● conectado ({port})", foreground="#080")
            self.connect_btn.configure(text="Desconectar")
            self.log(f"Conectado a {port} @ {self.baud_cb.get()} baud.")
        self._update_button_states()

    # --- Archivos / ejemplos --------------------------------------------------
    def open_file(self):
        path = filedialog.askopenfilename(
            initialdir=PROGRAMS_DIR,
            filetypes=[("Assembly", "*.s *.asm"), ("Todos", "*.*")])
        if path:
            self._load_text_from(path)

    def load_example(self, *_):
        name = self.example_cb.get()
        if name:
            self._load_text_from(os.path.join(PROGRAMS_DIR, name))

    def _load_text_from(self, path):
        with open(path) as f:
            self.editor.delete("1.0", "end")
            self.editor.insert("1.0", f.read())
        self.gutter.redraw()
        self.log(f"Cargado {os.path.basename(path)}.")

    def save_file(self):
        path = filedialog.asksaveasfilename(
            initialdir=PROGRAMS_DIR, defaultextension=".s",
            filetypes=[("Assembly", "*.s *.asm"), ("Todos", "*.*")])
        if path:
            with open(path, "w") as f:
                f.write(self.editor.get("1.0", "end-1c"))
            self.log(f"Guardado {os.path.basename(path)}.")

    # --- Ensamblado -----------------------------------------------------------
    def compile_source(self):
        try:
            self.words = assembler.assemble(self.editor.get("1.0", "end-1c"))
        except assembler.AssemblerError as e:
            self.log(f"Error de ensamblado: {e}", error=True)
            return False
        self.code_tv.delete(*self.code_tv.get_children())
        for i, w in enumerate(self.words):
            self.code_tv.insert("", "end", values=(i, f"{w:08x}", f"{w:032b}"))
        self.log(f"Compilado: {len(self.words)} instrucción(es).")
        return True

    # --- Operaciones contra la placa (en hilo aparte) -------------------------
    def _async(self, work, done):
        """Corre `work()` en un hilo y luego llama `done(result, error)` en el
        hilo de la UI. Evita congelar la ventana durante las esperas serie."""
        def run():
            try:
                result = work()
                self.after(0, lambda: done(result, None))
            except Exception as e:  # noqa: BLE001
                self.after(0, lambda: done(None, e))
        self._set_busy(True)
        threading.Thread(target=run, daemon=True).start()

    def _set_busy(self, busy):
        state = "disabled" if busy else "normal"
        for b in (self.btn_load, self.btn_run, self.btn_step, self.btn_info):
            b.configure(state=state if self.uart else "disabled")

    def send_program(self):
        if not self.words and not self.compile_source():
            return
        words = self.words
        self._async(lambda: self.uart.send_program(words), self._after_send)

    def _after_send(self, _result, error):
        self._set_busy(False)
        if error:
            self.log(f"Error enviando el programa: {error}", error=True)
            return
        self.in_step_mode = False
        self.log("Programa enviado (estado READY en la placa).")

    def run_continuous(self):
        def work():
            self.uart.send_command(uart.CMD_CONTINUE)
            return self.uart.receive_dump()
        self.in_step_mode = False
        self._async(work, self._after_dump)

    def run_step(self):
        def work():
            if not self.in_step_mode:
                self.uart.send_command(uart.CMD_STEP_BY_STEP)
            self.uart.send_command(uart.CMD_STEP)
            return self.uart.receive_dump()
        self._async(work, self._after_step_dump)

    def _after_step_dump(self, result, error):
        if not error:
            self.in_step_mode = True
        self._after_dump(result, error)

    def get_info(self):
        def work():
            self.uart.send_command(uart.CMD_SEND_INFO)
            return self.uart.receive_dump()
        self._async(work, self._after_dump)

    def _after_dump(self, result, error):
        self._set_busy(False)
        if error:
            self.log(f"Error leyendo el volcado: {error}", error=True)
            return
        pc, regs, mem = result
        self._show_dump(pc, regs, mem)
        self.log(f"Volcado recibido (PC = 0x{pc:016x}).")

    def _show_dump(self, pc, regs, mem):
        self.pc_lbl.configure(text=f"0x{pc:016x}")
        self.reg_tv.delete(*self.reg_tv.get_children())
        for i, v in enumerate(regs):
            self.reg_tv.insert("", "end", values=(f"x{i}", f"0x{v:016x}", v))
        self.mem_tv.delete(*self.mem_tv.get_children())
        for i, v in enumerate(mem):
            self.mem_tv.insert("", "end", values=(i, f"0x{v:016x}", v))

    def _on_close(self):
        if self.uart is not None:
            self.uart.close()
        self.destroy()


def main():
    DebugGui().mainloop()


if __name__ == "__main__":
    main()
