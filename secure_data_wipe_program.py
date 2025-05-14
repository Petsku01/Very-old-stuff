import tkinter as tk
from tkinter import messagebox
import ttkbootstrap as ttk
from ttkbootstrap.constants import *
import os
import shutil
import logging
from datetime import datetime
import getpass
import sys

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Handle PyInstaller/auto-py-to-exe resource paths
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for auto-py-to-exe."""
    try:
        base_path = sys._MEIPASS
    except AttributeError:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

class SecureWipeApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Secure Data Wipe Program")
        self.root.geometry("600x500")
        self.root.resizable(False, False)

        # Apply Tailwind-inspired theme
        self.style = ttk.Style(theme="darkly")

        # Main frame
        self.main_frame = ttk.Frame(self.root, padding=20)
        self.main_frame.pack(fill=BOTH, expand=True)

        # Warning label
        self.warning_label = ttk.Label(
            self.main_frame,
            text="WARNING: This program will SECURELY WIPE ALL accessible data on this device!\n"
                 "Data will be overwritten and UNRECOVERABLE. Proceed with extreme caution.",
            font=("Arial", 12, "bold"),
            foreground="red",
            wraplength=550,
            justify="center"
        )
        self.warning_label.pack(pady=10)

        # Instruction label
        self.instruction_label = ttk.Label(
            self.main_frame,
            text="To proceed, check the box, type 'SECURE WIPE' (case-sensitive), and click Confirm.",
            font=("Arial", 10),
            wraplength=550
        )
        self.instruction_label.pack(pady=10)

        # Checkbox
        self.confirm_var = tk.BooleanVar()
        self.confirm_check = ttk.Checkbutton(
            self.main_frame,
            text="I understand that all data will be securely wiped and unrecoverable",
            variable=self.confirm_var,
            style="danger.TCheckbutton"
        )
        self.confirm_check.pack(pady=10)

        # Confirmation text entry
        self.confirm_entry = ttk.Entry(self.main_frame, width=20, font=("Arial", 12))
        self.confirm_entry.pack(pady=10)
        self.confirm_entry.insert(0, "Type SECURE WIPE here")

        # Log text area
        self.log_text = tk.Text(self.main_frame, height=10, width=60, state="disabled")
        self.log_text.pack(pady=10)

        # Buttons frame
        self.button_frame = ttk.Frame(self.main_frame)
        self.button_frame.pack(pady=10)

        # Confirm button
        self.confirm_button = ttk.Button(
            self.button_frame,
            text="Confirm Wipe",
            command=self.start_wipe,
            style="danger.TButton"
        )
        self.confirm_button.pack(side=LEFT, padx=5)

        # Cancel button
        self.cancel_button = ttk.Button(
            self.button_frame,
            text="Cancel",
            command=self.cancel,
            style="secondary.TButton"
        )
        self.cancel_button.pack(side=LEFT, padx=5)

    def log_message(self, message, level="info"):
        """Log a message to the text area and logger."""
        self.log_text.config(state="normal")
        self.log_text.insert(tk.END, f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")
        self.log_text.config(state="disabled")
        self.log_text.see(tk.END)
        if level == "info":
            logger.info(message)
        elif level == "error":
            logger.error(message)

    def secure_overwrite_file(self, file_path):
        """Overwrite a file with random data before deletion."""
        try:
            file_size = os.path.getsize(file_path)
            if file_size == 0:
                os.remove(file_path)
                self.log_message(f"Deleted empty file: {file_path}")
                return
            with open(file_path, "wb") as f:
                f.write(os.urandom(file_size))  # Single-pass random overwrite
            self.log_message(f"Overwritten file: {file_path}")
            os.remove(file_path)
            self.log_message(f"Deleted file: {file_path}")
        except (PermissionError, OSError, FileNotFoundError) as e:
            self.log_message(f"Failed to wipe file {file_path}: {str(e)}", "error")

    def start_wipe(self):
        """Initiate the secure wipe process after validation."""
        if not self.confirm_var.get():
            messagebox.showerror("Error", "You must check the confirmation box.")
            self.log_message("Confirmation checkbox not checked.", "error")
            return

        if self.confirm_entry.get() != "SECURE WIPE":
            messagebox.showerror("Error", "You must type 'SECURE WIPE' exactly (case-sensitive).")
            self.log_message("Incorrect confirmation text entered.", "error")
            return

        # Final confirmation dialog
        if not messagebox.askyesno(
            "Final Confirmation",
            "Are you absolutely sure you want to SECURELY WIPE ALL data? This cannot be undone."
        ):
            self.log_message("Wipe cancelled by user in final confirmation.")
            return

        self.log_message("Starting secure wipe process...")
        self.confirm_button.config(state="disabled")
        self.cancel_button.config(state="disabled")

        # Run wipe in a separate thread to keep GUI responsive
        self.root.after(100, self.secure_wipe_data)

    def secure_wipe_data(self):
        """Securely wipe all accessible files and directories."""
        try:
            # Get user home directory
            home_dir = os.path.expanduser("~")
            self.log_message(f"Targeting home directory: {home_dir}")

            # Walk through the directory tree in bottom-up order
            for root, dirs, files in os.walk(home_dir, topdown=False):
                # Securely wipe files
                for file in files:
                    file_path = os.path.join(root, file)
                    self.secure_overwrite_file(file_path)

                # Delete directories (should be empty after file wiping)
                for dir in dirs:
                    dir_path = os.path.join(root, dir)
                    try:
                        shutil.rmtree(dir_path, ignore_errors=True)
                        self.log_message(f"Deleted directory: {dir_path}")
                    except (PermissionError, OSError) as e:
                        self.log_message(f"Failed to delete directory {dir_path}: {str(e)}", "error")

            self.log_message("Secure wipe process completed. Some system files may remain due to permissions.")
            messagebox.showinfo("Completed", "Secure wipe process finished. Some files may require admin privileges to wipe.")

        except Exception as e:
            self.log_message(f"Error during secure wipe: {str(e)}", "error")
            messagebox.showerror("Error", f"An error occurred: {str(e)}")

        finally:
            self.confirm_button.config(state="normal")
            self.cancel_button.config(state="normal")

    def cancel(self):
        """Cancel the operation and close the program."""
        self.log_message("Operation cancelled by user.")
        if messagebox.askyesno("Confirm Exit", "Are you sure you want to exit?"):
            self.root.destroy()

def main():
    root = ttk.Window()
    app = SecureWipeApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()