import tkinter as tk
from tkinter import messagebox, simpledialog
import json
from datetime import datetime
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import requests
import customtkinter
import os
import sys
import threading


class FitBuddyApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FitBuddy")
        self.root.geometry("400x550")
        self.root.resizable(False, False)
        self.set_window_icon()
        customtkinter.set_appearance_mode("Dark")
        customtkinter.set_default_color_theme("blue")
        self.bg_color = "#1E1E1E"
        self.text_color = "#FFFFFF"
        self.btn_color = "#333333"
        self.btn_hover_color = "#444444"
        self.entry_bg_color = "#2D2D2D"
        self.entry_fg_color = "#FFFFFF"
        self.center_main_window(400, 550)
        self.active_tooltips = []
        self.initialize_frames()
        self.nutrition_log = self.load_log("nutrition_log.json")
        self.workout_log = self.load_log("workout_log.json")
        self.saved_workouts = self.load_log("saved_workouts.json")
        self.saved_diets = self.load_log("saved_diets.json")

    def set_window_icon(self):
        try:
            if sys.platform.startswith('win'):
                icon_path = os.path.join(os.path.dirname(__file__), 'icons/bicep_icon.ico')
                self.root.iconbitmap(icon_path)
            else:
                icon_path = os.path.join(os.path.dirname(__file__), 'icons/bicep_icon.png')
                self.icon = tk.PhotoImage(file=icon_path)
                self.root.iconphoto(False, self.icon)
        except Exception as e:
            print(f"Error loading icon: {e}")

    def center_main_window(self, width, height):
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        x = int((screen_width / 2) - (width / 2))
        y = int((screen_height / 2) - (height / 2))
        self.root.geometry(f'{width}x{height}+{x}+{y}')

    def center_window(self, window, width, height, modal=False):
        main_window_x = self.root.winfo_x()
        main_window_y = self.root.winfo_y()
        main_window_width = self.root.winfo_width()
        main_window_height = self.root.winfo_height()
        x = main_window_x + (main_window_width // 2) - (width // 2)
        y = main_window_y + (main_window_height // 2) - (height // 2)
        window.geometry(f'{width}x{height}+{x}+{y}')
        window.transient(self.root)
        if modal:
            window.grab_set()
        window.focus_set()

    def disable_main_window_widgets(self):
        for widget in self.home_frame.winfo_children():
            self.recursive_disable(widget)

    def recursive_disable(self, widget):
        if isinstance(widget, (customtkinter.CTkButton, customtkinter.CTkEntry, customtkinter.CTkOptionMenu)):
            widget.configure(state="disabled")
        for child in widget.winfo_children():
            self.recursive_disable(child)

    def enable_main_window_widgets(self):
        for widget in self.home_frame.winfo_children():
            self.recursive_enable(widget)

    def recursive_enable(self, widget):
        if isinstance(widget, (customtkinter.CTkButton, customtkinter.CTkEntry, customtkinter.CTkOptionMenu)):
            widget.configure(state="normal")
        for child in widget.winfo_children():
            self.recursive_enable(child)

    def create_modal_window(self, title, width, height, setup_func):
        self.disable_main_window_widgets()
        modal_window = customtkinter.CTkToplevel(self.root)
        modal_window.title(title)
        self.center_window(modal_window, width, height, modal=False)
        modal_window.transient(self.root)
        modal_window.configure(fg_color=self.bg_color)

        def on_close():
            modal_window.destroy()
            self.enable_main_window_widgets()
            self.root.focus_set()

        modal_window.protocol("WM_DELETE_WINDOW", on_close)
        setup_func(modal_window)
        self.root.wait_window(modal_window)
        self.enable_main_window_widgets()
        self.root.focus_set()

    def initialize_frames(self):
        self.home_frame = customtkinter.CTkFrame(self.root, fg_color=self.bg_color)
        self.home_frame.pack(fill=tk.BOTH, expand=True)
        self.home_frame.pack_propagate(False)
        content_frame = customtkinter.CTkFrame(self.home_frame, fg_color=self.bg_color)
        content_frame.pack(expand=True)
        customtkinter.CTkLabel(content_frame, text="Welcome to FitBuddy", font=("Arial", 18, "bold"),
                               text_color=self.text_color).pack(pady=10)
        self.create_button(content_frame, "Nutrition Tracker", self.show_nutrition_tracker).pack(pady=5)
        self.create_button(content_frame, "Calorie Calculator", self.show_calorie_calculator).pack(pady=5)
        self.create_button(content_frame, "Workout Tracker", self.show_workout_tracker).pack(pady=5)
        self.create_button(content_frame, "Workout Builder", self.show_workout_builder).pack(pady=5)
        self.create_button(content_frame, "Create Diet", self.show_diet_generator).pack(pady=5)
        self.create_button(content_frame, "Exit", self.root.destroy).pack(pady=5)
        self.nutrition_tracker_frame = customtkinter.CTkFrame(self.root, fg_color=self.bg_color)
        self.calorie_calculator_frame = customtkinter.CTkFrame(self.root, fg_color=self.bg_color)
        self.workout_tracker_frame = customtkinter.CTkFrame(self.root, fg_color=self.bg_color)
        self.workout_builder_frame = customtkinter.CTkFrame(self.root, fg_color=self.bg_color)
        self.diet_generator_frame = customtkinter.CTkFrame(self.root, fg_color=self.bg_color)
        for frame in [self.nutrition_tracker_frame, self.calorie_calculator_frame,
                      self.workout_tracker_frame, self.workout_builder_frame,
                      self.diet_generator_frame]:
            frame.pack(fill=tk.BOTH, expand=True)
            frame.pack_forget()

    def show_frame(self, frame):
        self.hide_all_tooltips()
        frames = [self.home_frame, self.nutrition_tracker_frame, self.calorie_calculator_frame,
                  self.workout_tracker_frame, self.workout_builder_frame, self.diet_generator_frame]
        for frm in frames:
            frm.pack_forget()
        frame.pack(fill=tk.BOTH, expand=True)

    def create_button(self, parent, text, command):
        button = customtkinter.CTkButton(parent, text=text, command=command,
                                         fg_color=self.btn_color, hover_color=self.btn_hover_color,
                                         text_color=self.text_color, corner_radius=15,
                                         width=200, height=40)
        return button

    def back_to_home(self):
        self.show_frame(self.home_frame)

    def load_log(self, filename):
        try:
            with open(filename, "r") as file:
                return json.load(file)
        except FileNotFoundError:
            return {}

    def save_log(self, log_data, filename):
        with open(filename, "w") as file:
            json.dump(log_data, file, indent=4)

    def create_text_with_scrollbar(self, parent):
        text_frame = customtkinter.CTkFrame(parent, fg_color=self.bg_color)
        text_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        text_frame.grid_rowconfigure(0, weight=1)
        text_frame.grid_columnconfigure(0, weight=1)

        text_widget = tk.Text(text_frame, wrap=tk.WORD, state=tk.NORMAL, bg=self.entry_bg_color,
                              fg=self.entry_fg_color, insertbackground=self.entry_fg_color,
                              font=("Arial", 12), bd=0, relief=tk.FLAT)
        text_widget.grid(row=0, column=0, sticky="nsew")

        scrollbar = customtkinter.CTkScrollbar(text_frame, orientation="vertical", command=text_widget.yview, width=12)
        scrollbar.grid(row=0, column=1, sticky="ns")
        scrollbar.grid_remove()

        text_widget.configure(yscrollcommand=scrollbar.set)

        def update_scrollbar(event=None):
            first, last = text_widget.yview()
            if last - first >= 1.0:
                scrollbar.grid_remove()
            else:
                scrollbar.grid()

        text_widget.bind('<Configure>', update_scrollbar)
        text_widget.bind('<<Modified>>', update_scrollbar)
        text_widget.edit_modified(False)

        return text_widget, update_scrollbar

    def show_nutrition_tracker(self):
        self.show_frame(self.nutrition_tracker_frame)
        for widget in self.nutrition_tracker_frame.winfo_children():
            widget.destroy()
        content_frame = customtkinter.CTkFrame(self.nutrition_tracker_frame, fg_color=self.bg_color)
        content_frame.pack(expand=True)
        customtkinter.CTkLabel(content_frame, text="Nutrition Tracker", font=("Arial", 18, "bold"),
                               text_color=self.text_color).pack(pady=10)
        self.nutrition_entries = {}
        nutrients = ["Calories", "Fat", "Protein", "Carbohydrates", "Fiber"]
        for nutrient in nutrients:
            frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
            frame.pack(pady=5)
            customtkinter.CTkLabel(frame, text=nutrient, font=("Arial", 12),
                                   text_color=self.text_color).pack(side=tk.LEFT, padx=5)
            entry = customtkinter.CTkEntry(frame, font=("Arial", 12),
                                           fg_color=self.entry_bg_color, text_color=self.entry_fg_color)
            entry.pack(side=tk.LEFT, padx=5)
            self.nutrition_entries[nutrient] = entry
        buttons_frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
        buttons_frame.pack(pady=5)
        self.create_button(buttons_frame, "Save Entry", self.save_nutrition_entry).pack(pady=5)
        self.create_button(buttons_frame, "View Log", self.view_nutrition_log).pack(pady=5)
        self.create_button(buttons_frame, "Visualizations", self.view_nutrition_visualization).pack(pady=5)
        self.create_button(buttons_frame, "Back", self.back_to_home).pack(pady=5)

    def save_nutrition_entry(self):
        try:
            entry_data = {key: float(self.nutrition_entries[key].get()) for key in self.nutrition_entries}
            date = datetime.now().strftime("%Y-%m-%d")
            if date not in self.nutrition_log:
                self.nutrition_log[date] = []
            MAX_ENTRIES_PER_DATE = 50
            if len(self.nutrition_log[date]) >= MAX_ENTRIES_PER_DATE:
                self.nutrition_log[date].pop(0)
            self.nutrition_log[date].append(entry_data)
            self.save_log(self.nutrition_log, "nutrition_log.json")
            messagebox.showinfo("Success", "Entry saved successfully!")
            for entry in self.nutrition_entries.values():
                entry.delete(0, tk.END)
        except ValueError:
            messagebox.showerror("Error", "Please enter valid numbers.")

    def view_nutrition_log(self):
        def setup_nutrition_log(log_window):
            log_window.grid_rowconfigure(0, weight=1)
            log_window.grid_columnconfigure(0, weight=1)
            log_text, update_scrollbar = self.create_text_with_scrollbar(log_window)
            has_entries = bool(self.nutrition_log and any(self.nutrition_log.values()))
            if has_entries:
                for date, entries in self.nutrition_log.items():
                    log_text.insert(tk.END, f"Date: {date}\n", "date_tag")
                    for entry in entries:
                        log_text.insert(tk.END,
                                        f"  Calories: {entry['Calories']} | Fat: {entry['Fat']} | Protein: {entry['Protein']} | Carbs: {entry['Carbohydrates']} | Fiber: {entry['Fiber']}\n")
                    log_text.insert(tk.END, "\n")
                log_text.config(state=tk.DISABLED)
                log_text.edit_modified(True)
                update_scrollbar()
                buttons_frame = customtkinter.CTkFrame(log_window, fg_color=self.bg_color)
                buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
                buttons_frame.grid_columnconfigure(0, weight=1)
                buttons_frame.grid_columnconfigure(1, weight=1)
                clear_button = self.create_button(buttons_frame, "Clear Log",
                                                  lambda: self.clear_nutrition_log(log_window))
                clear_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
                exit_button = self.create_button(buttons_frame, "Exit", log_window.destroy)
                exit_button.grid(row=0, column=1, padx=5, pady=5, sticky="ew")
            else:
                log_text.insert(tk.END, "No entries to display.")
                log_text.config(state=tk.DISABLED)
                log_text.edit_modified(True)
                update_scrollbar()
                buttons_frame = customtkinter.CTkFrame(log_window, fg_color=self.bg_color)
                buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
                buttons_frame.grid_columnconfigure(0, weight=1)
                close_button = self.create_button(buttons_frame, "Close", log_window.destroy)
                close_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")

        self.create_modal_window("Nutrition Log", 400, 500, setup_nutrition_log)

    def clear_nutrition_log(self, log_window):
        if not self.nutrition_log or not any(self.nutrition_log.values()):
            messagebox.showerror("Error", "There are no entries to clear.")
        elif len(self.nutrition_log) > 1:
            selected_date = self.select_date_from_log(self.nutrition_log)
            if selected_date:
                del self.nutrition_log[selected_date]
                self.save_log(self.nutrition_log, "nutrition_log.json")
                messagebox.showinfo("Log Cleared", f"Entries for {selected_date} have been cleared.")
                log_window.destroy()
        else:
            self.nutrition_log.clear()
            self.save_log(self.nutrition_log, "nutrition_log.json")
            log_window.destroy()
            messagebox.showinfo("Log Cleared", "All entries have been cleared.")

    def view_nutrition_visualization(self):
        if not self.nutrition_log:
            messagebox.showinfo("No Data", "No nutrition data available to visualize.")
            return
        if len(self.nutrition_log) > 1:
            date = self.select_date_from_log(self.nutrition_log)
        else:
            date = list(self.nutrition_log.keys())[0]
        if date:
            self.visualize_nutrition_data(date)

    def visualize_nutrition_data(self, date):
        if date not in self.nutrition_log:
            messagebox.showinfo("No Data", "No data available for the selected date.")
            return
        nutrient_keys = ["Calories", "Fat", "Protein", "Carbohydrates", "Fiber"]
        nutrient_labels = ["Calories", "Fat", "Protein", "Carbs", "Fiber"]
        values = [0] * len(nutrient_keys)
        for entry in self.nutrition_log[date]:
            for i, nutrient in enumerate(nutrient_keys):
                values[i] += entry.get(nutrient, 0)
        fig, ax = plt.subplots(figsize=(10, 6))
        ax.bar(nutrient_labels, values, color=['blue', 'green', 'red', 'purple', 'orange'])
        ax.set_xlabel("Nutrients")
        ax.set_ylabel("Amount")
        ax.set_title(f"Nutrition Breakdown for {date}")
        ax.grid(True)
        self.show_plot_in_new_window(fig)

    def show_calorie_calculator(self):
        self.show_frame(self.calorie_calculator_frame)
        for widget in self.calorie_calculator_frame.winfo_children():
            widget.destroy()
        content_frame = customtkinter.CTkFrame(self.calorie_calculator_frame, fg_color=self.bg_color)
        content_frame.pack(expand=True)
        customtkinter.CTkLabel(content_frame, text="Calorie Calculator", font=("Arial", 18, "bold"),
                               text_color=self.text_color).pack(pady=10)
        self.calorie_entries = {}
        labels = ["Age (years)", "Gender", "Height (cm)", "Weight (kg)", "Activity Level"]
        for label_text in labels:
            frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
            frame.pack(pady=5)
            customtkinter.CTkLabel(frame, text=label_text, font=("Arial", 12),
                                   text_color=self.text_color).pack(side=tk.LEFT, padx=5)
            if label_text == "Gender":
                gender_var = tk.StringVar(value="Male")
                gender_menu = customtkinter.CTkOptionMenu(frame, variable=gender_var, values=["Male", "Female"],
                                                          fg_color=self.entry_bg_color, text_color=self.text_color,
                                                          button_color=self.btn_color,
                                                          button_hover_color=self.btn_hover_color)
                gender_menu.pack(side=tk.LEFT, padx=5)
                self.calorie_entries['gender'] = gender_var
            elif label_text == "Activity Level":
                activity_var = tk.StringVar(value="Sedentary")
                activity_menu = customtkinter.CTkOptionMenu(frame, variable=activity_var,
                                                            values=["Sedentary", "Lightly active", "Moderately active",
                                                                    "Very active", "Super active"],
                                                            fg_color=self.entry_bg_color, text_color=self.text_color,
                                                            button_color=self.btn_color,
                                                            button_hover_color=self.btn_hover_color)
                activity_menu.pack(side=tk.LEFT, padx=5)
                self.calorie_entries['activity'] = activity_var
            else:
                entry = customtkinter.CTkEntry(frame, font=("Arial", 12),
                                               fg_color=self.entry_bg_color, text_color=self.entry_fg_color)
                entry.pack(side=tk.LEFT, padx=5)
                key = label_text.split(" ")[0].lower()
                self.calorie_entries[key] = entry
        buttons_frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
        buttons_frame.pack(pady=5)
        self.create_button(buttons_frame, "Calculate", self.calculate_calories).pack(pady=5)
        self.create_button(buttons_frame, "Back", self.back_to_home).pack(pady=5)

    def calculate_calories(self):
        try:
            age = int(self.calorie_entries['age'].get())
            gender = self.calorie_entries['gender'].get()
            height = float(self.calorie_entries['height'].get())
            weight = float(self.calorie_entries['weight'].get())
            activity_level = self.calorie_entries['activity'].get()
            if gender == "Male":
                bmr = 10 * weight + 6.25 * height - 5 * age + 5
            else:
                bmr = 10 * weight + 6.25 * height - 5 * age - 161
            activity_multiplier = {
                "Sedentary": 1.2,
                "Lightly active": 1.375,
                "Moderately active": 1.55,
                "Very active": 1.725,
                "Super active": 1.9
            }
            daily_calories = bmr * activity_multiplier[activity_level]
            messagebox.showinfo("Calorie Needs",
                                f"Your daily calorie needs are approximately {int(daily_calories)} calories.")
        except ValueError:
            messagebox.showerror("Error", "Please enter valid information.")

    def show_workout_tracker(self):
        self.show_frame(self.workout_tracker_frame)
        for widget in self.workout_tracker_frame.winfo_children():
            widget.destroy()
        content_frame = customtkinter.CTkFrame(self.workout_tracker_frame, fg_color=self.bg_color)
        content_frame.pack(expand=True)
        customtkinter.CTkLabel(content_frame, text="Workout Tracker", font=("Arial", 18, "bold"),
                               text_color=self.text_color).pack(pady=10)
        self.workout_entries = {}
        labels = ["Workout Type", "Exercises", "Sets", "Reps"]
        for label_text in labels:
            frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
            frame.pack(pady=5)
            customtkinter.CTkLabel(frame, text=label_text, font=("Arial", 12),
                                   text_color=self.text_color).pack(side=tk.LEFT, padx=5)
            if label_text == "Workout Type":
                workout_type_var = tk.StringVar(value="Legs")
                option_menu = customtkinter.CTkOptionMenu(frame, variable=workout_type_var,
                                                          values=["Legs", "Arms", "Abs", "Back", "Shoulders"],
                                                          fg_color=self.entry_bg_color, text_color=self.text_color,
                                                          button_color=self.btn_color,
                                                          button_hover_color=self.btn_hover_color)
                option_menu.pack(side=tk.LEFT, padx=5)
                self.workout_entries['workout_type'] = workout_type_var
            else:
                entry = customtkinter.CTkEntry(frame, font=("Arial", 12),
                                               fg_color=self.entry_bg_color, text_color=self.entry_fg_color)
                entry.pack(side=tk.LEFT, padx=5)
                key = label_text.lower().replace(" ", "_")
                self.workout_entries[key] = entry
        buttons_frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
        buttons_frame.pack(pady=5)
        self.create_button(buttons_frame, "Save Workout", self.save_workout_entry).pack(pady=5)
        self.create_button(buttons_frame, "View Log", self.view_workout_log).pack(pady=5)
        self.create_button(buttons_frame, "Visualizations", self.view_workout_visualization).pack(pady=5)
        self.create_button(buttons_frame, "Back", self.back_to_home).pack(pady=5)

    def save_workout_entry(self):
        try:
            workout_data = {
                "workout_type": self.workout_entries['workout_type'].get(),
                "exercises": self.workout_entries['exercises'].get(),
                "sets": int(self.workout_entries['sets'].get()),
                "reps": int(self.workout_entries['reps'].get())
            }
            date = datetime.now().strftime("%Y-%m-%d")
            if date not in self.workout_log:
                self.workout_log[date] = []
            MAX_ENTRIES_PER_DATE = 50
            if len(self.workout_log[date]) >= MAX_ENTRIES_PER_DATE:
                self.workout_log[date].pop(0)
            self.workout_log[date].append(workout_data)
            self.save_log(self.workout_log, "workout_log.json")
            messagebox.showinfo("Success", "Workout saved successfully!")
            for entry in self.workout_entries.values():
                if isinstance(entry, customtkinter.CTkEntry):
                    entry.delete(0, tk.END)
        except ValueError:
            messagebox.showerror("Error", "Please enter valid numbers for sets and reps.")

    def view_workout_log(self):
        def setup_workout_log(log_window):
            log_window.grid_rowconfigure(0, weight=1)
            log_window.grid_columnconfigure(0, weight=1)
            log_text, update_scrollbar = self.create_text_with_scrollbar(log_window)
            has_entries = bool(self.workout_log and any(self.workout_log.values()))
            if has_entries:
                for date, entries in self.workout_log.items():
                    log_text.insert(tk.END, f"Date: {date}\n", "date_tag")
                    for entry in entries:
                        log_text.insert(tk.END,
                                        f"  Workout: {entry['workout_type']} | Exercises: {entry['exercises']} | Sets: {entry['sets']} | Reps: {entry['reps']}\n")
                    log_text.insert(tk.END, "\n")
                log_text.config(state=tk.DISABLED)
                log_text.edit_modified(True)
                update_scrollbar()
                buttons_frame = customtkinter.CTkFrame(log_window, fg_color=self.bg_color)
                buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
                buttons_frame.grid_columnconfigure(0, weight=1)
                buttons_frame.grid_columnconfigure(1, weight=1)
                clear_button = self.create_button(buttons_frame, "Clear Log",
                                                  lambda: self.clear_workout_log(log_window))
                clear_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
                exit_button = self.create_button(buttons_frame, "Exit", log_window.destroy)
                exit_button.grid(row=0, column=1, padx=5, pady=5, sticky="ew")
            else:
                log_text.insert(tk.END, "No entries to display.")
                log_text.config(state=tk.DISABLED)
                log_text.edit_modified(True)
                update_scrollbar()
                buttons_frame = customtkinter.CTkFrame(log_window, fg_color=self.bg_color)
                buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
                buttons_frame.grid_columnconfigure(0, weight=1)
                close_button = self.create_button(buttons_frame, "Close", log_window.destroy)
                close_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")

        self.create_modal_window("Workout Log", 400, 500, setup_workout_log)

    def clear_workout_log(self, log_window):
        if not self.workout_log or not any(self.workout_log.values()):
            messagebox.showerror("Error", "There are no entries to clear.")
        elif len(self.workout_log) > 1:
            selected_date = self.select_date_from_log(self.workout_log)
            if selected_date:
                del self.workout_log[selected_date]
                self.save_log(self.workout_log, "workout_log.json")
                messagebox.showinfo("Log Cleared", f"Entries for {selected_date} have been cleared.")
                log_window.destroy()
        else:
            self.workout_log.clear()
            self.save_log(self.workout_log, "workout_log.json")
            log_window.destroy()
            messagebox.showinfo("Log Cleared", "All entries have been cleared.")

    def view_workout_visualization(self):
        if not self.workout_log:
            messagebox.showinfo("No Data", "No workout data available to visualize.")
            return
        if len(self.workout_log) > 1:
            date = self.select_date_from_log(self.workout_log)
        else:
            date = list(self.workout_log.keys())[0]
        if date:
            self.visualize_workout_data(date)

    def visualize_workout_data(self, date):
        if date not in self.workout_log:
            messagebox.showinfo("No Data", "No data available for the selected date.")
            return
        exercises = []
        sets = []
        reps = []
        for entry in self.workout_log[date]:
            exercise_name = entry['exercises']
            exercises.append(exercise_name)
            sets.append(entry['sets'])
            reps.append(entry['reps'])
        fig, ax = plt.subplots(figsize=(12, 8))
        bar_width = 0.35
        index = range(len(exercises))
        ax.bar(index, sets, bar_width, label="Sets", color='blue')
        ax.bar([i + bar_width for i in index], reps, bar_width, label="Reps", color='green')
        ax.set_xlabel("Exercises")
        ax.set_ylabel("Amount")
        ax.set_title(f"Workout Summary for {date}")
        ax.set_xticks([i + bar_width / 2 for i in index])
        ax.set_xticklabels(exercises, rotation=45, ha='right')
        ax.legend()
        ax.grid(True)
        self.show_plot_in_new_window(fig, width=500, height=900)

    def show_workout_builder(self):
        self.show_frame(self.workout_builder_frame)
        for widget in self.workout_builder_frame.winfo_children():
            widget.destroy()
        content_frame = customtkinter.CTkFrame(self.workout_builder_frame, fg_color=self.bg_color)
        content_frame.pack(expand=True)
        customtkinter.CTkLabel(content_frame, text="Workout Builder", font=("Arial", 18, "bold"),
                               text_color=self.text_color).pack(pady=10)
        self.workout_builder_entries = {}
        labels = ["Goal", "Intensity", "Duration (mins)", "Body Type", "Dietary Preference", "Fitness Level"]
        options = {
            "Goal": ["Build Muscle", "Lose Weight", "Improve Endurance", "Increase Flexibility"],
            "Intensity": ["Low", "Moderate", "High"],
            "Body Type": ["Ectomorph", "Mesomorph", "Endomorph"],
            "Dietary Preference": ["General Balanced Diet", "Keto", "Vegan", "Vegetarian", "Paleo"],
            "Fitness Level": ["Beginner", "Intermediate", "Advanced"]
        }
        for label_text in labels:
            frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
            frame.pack(pady=5)
            label = customtkinter.CTkLabel(frame, text=label_text, font=("Arial", 12),
                                           text_color=self.text_color)
            label.pack(side=tk.LEFT, padx=5)
            if label_text in ["Body Type", "Dietary Preference"]:
                tooltip_text = ""
                if label_text == "Body Type":
                    tooltip_text = "Body Type refers to your physique classification:\n- Ectomorph: Lean, difficulty gaining weight.\n- Mesomorph: Muscular, easy to gain muscle.\n- Endomorph: Softer, tendency to store fat."
                elif label_text == "Dietary Preference":
                    tooltip_text = ("Dietary Preference allows you to select your diet type:\n"
                                    "- General Balanced Diet: A diet including a variety of foods from all food groups.\n"
                                    "- Keto: Low-carb, high-fat diet.\n"
                                    "- Vegan: Excludes all animal products.\n"
                                    "- Vegetarian: Excludes meat but may include dairy and eggs.\n"
                                    "- Paleo: Focuses on foods presumed to be available to Paleolithic humans.")
                if tooltip_text:
                    tooltip_label = self.create_tooltip_label(frame, tooltip_text)
                    tooltip_label.pack(side=tk.LEFT, padx=2)
            if label_text in options:
                var = tk.StringVar(value=options[label_text][0])
                menu = customtkinter.CTkOptionMenu(frame, variable=var, values=options[label_text],
                                                   fg_color=self.entry_bg_color, text_color=self.text_color,
                                                   button_color=self.btn_color, button_hover_color=self.btn_hover_color)
                menu.pack(side=tk.LEFT, padx=5)
                key = label_text.lower().replace(" ", "_")
                self.workout_builder_entries[key] = var
            elif label_text == "Duration (mins)":
                entry = customtkinter.CTkEntry(frame, font=("Arial", 12),
                                               fg_color=self.entry_bg_color, text_color=self.entry_fg_color)
                entry.pack(side=tk.LEFT, padx=5)
                self.workout_builder_entries['duration'] = entry
        buttons_frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
        buttons_frame.pack(pady=5)
        self.create_button(buttons_frame, "Generate Workout", self.generate_workout).pack(pady=5)
        self.create_button(buttons_frame, "View Workouts", self.view_saved_workouts).pack(pady=5)
        self.create_button(buttons_frame, "Back", self.back_to_home).pack(pady=5)

    def generate_workout(self):
        try:
            goal = self.workout_builder_entries['goal'].get()
            intensity = self.workout_builder_entries['intensity'].get()
            duration = int(self.workout_builder_entries['duration'].get())
            body_type = self.workout_builder_entries['body_type'].get()
        except ValueError:
            messagebox.showerror("Error", "Please enter a valid duration.")
            return
        threading.Thread(
            target=self.fetch_workout_plan,
            args=(goal, intensity, duration, body_type),
            daemon=True
        ).start()

    def fetch_workout_plan(self, goal, intensity, duration, body_type):
        try:
            response = requests.post(
                "https://fitbuddy-backend-ruby.vercel.app/generate_workout/",
                data={
                    "goal": goal,
                    "intensity": intensity,
                    "duration": duration,
                    "body_type": body_type,
                }
            )
            if response.status_code == 200:
                workout_plan = response.json().get('workout', 'No plan found.')
                self.root.after(0, lambda: self.show_workout_plan(workout_plan))
            else:
                self.root.after(0, lambda: messagebox.showerror("Error", "Failed to generate a workout plan."))
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", f"An error occurred: {str(e)}"))

    def show_workout_plan(self, workout_plan):
        workout_plan_window = customtkinter.CTkToplevel(self.root)
        workout_plan_window.title("Generated Workout Plan")
        self.center_window(workout_plan_window, 400, 500, modal=False)
        workout_plan_window.configure(fg_color=self.bg_color)
        workout_plan_window.grid_rowconfigure(0, weight=1)
        workout_plan_window.grid_columnconfigure(0, weight=1)
        plan_text, update_scrollbar = self.create_text_with_scrollbar(workout_plan_window)
        plan_text.insert(tk.END, workout_plan)
        plan_text.config(state=tk.DISABLED)
        plan_text.edit_modified(True)
        update_scrollbar()
        buttons_frame = customtkinter.CTkFrame(workout_plan_window, fg_color=self.bg_color)
        buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
        buttons_frame.grid_columnconfigure(0, weight=1)
        buttons_frame.grid_columnconfigure(1, weight=1)
        save_button = self.create_button(buttons_frame, "Save Workout",
                                         lambda: self.save_generated_plan(workout_plan, "saved_workouts.json",
                                                                          self.saved_workouts))
        save_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
        close_button = self.create_button(buttons_frame, "Close", workout_plan_window.destroy)
        close_button.grid(row=0, column=1, padx=5, pady=5, sticky="ew")

    def save_generated_plan(self, plan, filename, log):
        date = datetime.now().strftime("%Y-%m-%d")
        if date not in log:
            log[date] = []
        MAX_PLANS_PER_DATE = 20
        if len(log[date]) >= MAX_PLANS_PER_DATE:
            log[date].pop(0)
        log[date].append(plan)
        self.save_log(log, filename)
        messagebox.showinfo("Success", "Plan saved successfully!")

    def view_saved_workouts(self):
        if not self.saved_workouts:
            messagebox.showinfo("No Data", "No saved workouts available.")
            return
        if len(self.saved_workouts) > 1:
            date = self.select_date_from_log(self.saved_workouts)
        else:
            date = list(self.saved_workouts.keys())[0]
        if date:
            self.show_saved_plans(self.saved_workouts[date], "Workout", "saved_workouts.json", self.saved_workouts)

    def show_diet_generator(self):
        self.show_frame(self.diet_generator_frame)
        for widget in self.diet_generator_frame.winfo_children():
            widget.destroy()
        content_frame = customtkinter.CTkFrame(self.diet_generator_frame, fg_color=self.bg_color)
        content_frame.pack(expand=True)
        customtkinter.CTkLabel(content_frame, text="Create Healthy Diet", font=("Arial", 18, "bold"),
                               text_color=self.text_color).pack(pady=10)
        self.diet_entries = {}
        labels = ["Dietary Preference", "Goal", "Body Type"]
        options = {
            "Dietary Preference": ["General Balanced Diet", "Keto", "Vegan", "Vegetarian", "Paleo"],
            "Goal": ["Lose Weight", "Build Muscle", "Maintain Weight", "Improve Health"],
            "Body Type": ["Ectomorph", "Mesomorph", "Endomorph"]
        }
        for label_text in labels:
            frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
            frame.pack(pady=5)
            label = customtkinter.CTkLabel(frame, text=label_text, font=("Arial", 12),
                                           text_color=self.text_color)
            label.pack(side=tk.LEFT, padx=5)
            if label_text in ["Body Type", "Dietary Preference"]:
                tooltip_text = ""
                if label_text == "Body Type":
                    tooltip_text = "Body Type refers to your physique classification:\n- Ectomorph: Lean, difficulty gaining weight.\n- Mesomorph: Muscular, easy to gain muscle.\n- Endomorph: Softer, tendency to store fat."
                elif label_text == "Dietary Preference":
                    tooltip_text = ("Dietary Preference allows you to select your diet type:\n"
                                    "- General Balanced Diet: A diet including a variety of foods from all food groups.\n"
                                    "- Keto: Low-carb, high-fat diet.\n"
                                    "- Vegan: Excludes all animal products.\n"
                                    "- Vegetarian: Excludes meat but may include dairy and eggs.\n"
                                    "- Paleo: Focuses on foods presumed to be available to Paleolithic humans.")
                if tooltip_text:
                    tooltip_label = self.create_tooltip_label(frame, tooltip_text)
                    tooltip_label.pack(side=tk.LEFT, padx=2)
            var = tk.StringVar(value=options[label_text][0])
            menu = customtkinter.CTkOptionMenu(frame, variable=var, values=options[label_text],
                                               fg_color=self.entry_bg_color, text_color=self.text_color,
                                               button_color=self.btn_color, button_hover_color=self.btn_hover_color)
            menu.pack(side=tk.LEFT, padx=5)
            key = label_text.lower().replace(" ", "_")
            self.diet_entries[key] = var
        buttons_frame = customtkinter.CTkFrame(content_frame, fg_color=self.bg_color)
        buttons_frame.pack(pady=5)
        self.create_button(buttons_frame, "Generate Diet Plan", self.generate_diet_plan).pack(pady=5)
        self.create_button(buttons_frame, "View Diets", self.view_saved_diets).pack(pady=5)
        self.create_button(buttons_frame, "Back", self.back_to_home).pack(pady=5)

    def generate_diet_plan(self):
        try:
            diet = self.diet_entries['dietary_preference'].get()
            goal = self.diet_entries['goal'].get()
            body_type = self.diet_entries['body_type'].get()
        except Exception as e:
            messagebox.showerror("Error", f"Invalid input: {str(e)}")
            return
        threading.Thread(
            target=self.fetch_diet_plan,
            args=(diet, goal, body_type),
            daemon=True
        ).start()

    def fetch_diet_plan(self, diet, goal, body_type):
        try:
            response = requests.post(
                "https://fitbuddy-backend-ruby.vercel.app/generate_diet/",
                data={
                    "diet_preference": diet,
                    "goal": goal,
                    "body_type": body_type,
                }
            )
            if response.status_code == 200:
                diet_plan = response.json().get('diet', 'No plan found.')
                self.root.after(0, lambda: self.show_diet_plan(diet_plan))
            else:
                self.root.after(0, lambda: messagebox.showerror("Error", "Failed to generate a diet plan."))
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", f"An error occurred: {str(e)}"))

    def show_diet_plan(self, diet_plan):
        diet_plan_window = customtkinter.CTkToplevel(self.root)
        diet_plan_window.title("Generated Diet Plan")
        self.center_window(diet_plan_window, 400, 500, modal=False)
        diet_plan_window.configure(fg_color=self.bg_color)
        diet_plan_window.grid_rowconfigure(0, weight=1)
        diet_plan_window.grid_columnconfigure(0, weight=1)
        plan_text, update_scrollbar = self.create_text_with_scrollbar(diet_plan_window)
        plan_text.insert(tk.END, diet_plan)
        plan_text.config(state=tk.DISABLED)
        plan_text.edit_modified(True)
        update_scrollbar()
        buttons_frame = customtkinter.CTkFrame(diet_plan_window, fg_color=self.bg_color)
        buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
        buttons_frame.grid_columnconfigure(0, weight=1)
        buttons_frame.grid_columnconfigure(1, weight=1)
        save_button = self.create_button(buttons_frame, "Save Diet",
                                         lambda: self.save_generated_plan(diet_plan, "saved_diets.json",
                                                                          self.saved_diets))
        save_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
        close_button = self.create_button(buttons_frame, "Close", diet_plan_window.destroy)
        close_button.grid(row=0, column=1, padx=5, pady=5, sticky="ew")

    def view_saved_diets(self):
        if not self.saved_diets:
            messagebox.showinfo("No Data", "No saved diets available.")
            return
        if len(self.saved_diets) > 1:
            date = self.select_date_from_log(self.saved_diets)
        else:
            date = list(self.saved_diets.keys())[0]
        if date:
            self.show_saved_plans(self.saved_diets[date], "Diet", "saved_diets.json", self.saved_diets)

    def show_plot_in_new_window(self, fig, width=440, height=500):
        plot_window = customtkinter.CTkToplevel(self.root)
        plot_window.title("Visualization")
        self.center_window(plot_window, width, height, modal=False)
        plot_window.configure(fg_color=self.bg_color)
        plot_window.grid_rowconfigure(0, weight=1)
        plot_window.grid_columnconfigure(0, weight=1)
        canvas = FigureCanvasTkAgg(fig, master=plot_window)
        canvas.draw()
        canvas.get_tk_widget().grid(row=0, column=0, padx=10, pady=10, sticky="nsew")

        def on_close():
            plt.close(fig)
            plot_window.destroy()

        plot_window.protocol("WM_DELETE_WINDOW", on_close)
        close_button = self.create_button(plot_window, "Close", on_close)
        close_button.grid(row=1, column=0, padx=10, pady=10, sticky="ew")

    def select_date_from_log(self, log):
        dates = list(log.keys())
        if not dates:
            messagebox.showinfo("No Data", "No data available to select.")
            return None
        self.selected_date = None

        def setup_date_select_window(date_select_window):
            date_select_window.grid_rowconfigure(0, weight=1)
            date_select_window.grid_columnconfigure(0, weight=1)
            date_select_window.grid_columnconfigure(1, weight=1)
            customtkinter.CTkLabel(date_select_window, text="Select a date:", text_color=self.text_color,
                                   font=("Arial", 12)).pack(pady=10)
            selected_date = tk.StringVar(value=dates[0])
            dropdown = customtkinter.CTkOptionMenu(date_select_window, variable=selected_date, values=dates,
                                                   fg_color=self.entry_bg_color, text_color=self.text_color,
                                                   button_color=self.btn_color, button_hover_color=self.btn_hover_color)
            dropdown.pack(pady=10)

            def confirm_selection():
                self.selected_date = selected_date.get()
                date_select_window.destroy()

            confirm_button = self.create_button(date_select_window, "Confirm", confirm_selection)
            confirm_button.pack(pady=10)

        self.create_modal_window("Select Date", 300, 150, setup_date_select_window)
        return self.selected_date

    def show_saved_plans(self, plans, plan_type, filename, log):
        if not plans:
            messagebox.showinfo("No Data", f"No saved {plan_type.lower()}s available.")
            return
        plan_window = customtkinter.CTkToplevel(self.root)
        plan_window.title(f"Saved {plan_type}s")
        self.center_window(plan_window, 400, 500, modal=False)
        plan_window.configure(fg_color=self.bg_color)
        plan_window.grid_rowconfigure(0, weight=1)
        plan_window.grid_columnconfigure(0, weight=1)
        plan_text, update_scrollbar = self.create_text_with_scrollbar(plan_window)
        for i, plan in enumerate(plans, start=1):
            plan_text.insert(tk.END, f"{plan_type} {i}:\n{plan}\n\n")
        plan_text.config(state=tk.DISABLED)
        plan_text.edit_modified(True)
        update_scrollbar()
        buttons_frame = customtkinter.CTkFrame(plan_window, fg_color=self.bg_color)
        buttons_frame.grid(row=1, column=0, padx=10, pady=10, sticky="ew")
        buttons_frame.grid_columnconfigure(0, weight=1)
        buttons_frame.grid_columnconfigure(1, weight=1)

        def clear_saved_plan():
            if len(plans) > 1:
                selected_plan_index = simpledialog.askinteger(
                    "Select Plan",
                    f"Enter the number of the {plan_type.lower()} to delete (1-{len(plans)}):",
                    minvalue=1,
                    maxvalue=len(plans)
                )
                if selected_plan_index is not None:
                    del plans[selected_plan_index - 1]
                    if not plans:
                        for date_key, date_plans in log.items():
                            if date_plans == plans:
                                del log[date_key]
                                break
                    self.save_log(log, filename)
                    plan_window.destroy()
                    messagebox.showinfo("Success", f"{plan_type} deleted successfully!")
            else:
                confirm = messagebox.askyesno("Confirm Deletion",
                                              f"Are you sure you want to delete the only {plan_type.lower()}?")
                if confirm:
                    del plans[0]
                    if not plans:
                        for date_key, date_plans in log.items():
                            if date_plans == plans:
                                del log[date_key]
                                break
                    self.save_log(log, filename)
                    plan_window.destroy()
                    messagebox.showinfo("Success", f"{plan_type} deleted successfully!")

        clear_button = self.create_button(buttons_frame, "Clear", clear_saved_plan)
        clear_button.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
        close_button = self.create_button(buttons_frame, "Close", plan_window.destroy)
        close_button.grid(row=0, column=1, padx=5, pady=5, sticky="ew")

    def create_tooltip_label(self, parent, tooltip_text):
        tooltip_label = customtkinter.CTkLabel(parent, text="?", font=("Arial", 10, "bold"),
                                               text_color=self.text_color, fg_color=self.entry_bg_color,
                                               corner_radius=10, width=20, height=20)
        tooltip_label.configure(anchor="center")

        def show_tooltip(event):
            self.hide_all_tooltips()
            tooltip_window = customtkinter.CTkToplevel(self.root)
            tooltip_window.overrideredirect(True)
            tooltip_window.configure(fg_color=self.bg_color)
            label = customtkinter.CTkLabel(tooltip_window, text=tooltip_text, text_color=self.text_color,
                                           fg_color=self.bg_color, wraplength=200)
            label.pack()
            x = event.widget.winfo_rootx() + 20
            y = event.widget.winfo_rooty() + 20
            tooltip_window.geometry(f"+{x}+{y}")
            self.active_tooltips.append(tooltip_window)
            tooltip_window.bind("<Enter>", lambda e: None)
            tooltip_window.bind("<Leave>", lambda e: self.hide_all_tooltips())

        def hide_tooltip(event=None):
            self.hide_all_tooltips()

        tooltip_label.bind("<Enter>", show_tooltip)
        tooltip_label.bind("<Leave>", hide_tooltip)

        return tooltip_label

    def hide_all_tooltips(self):
        while self.active_tooltips:
            tooltip = self.active_tooltips.pop()
            tooltip.destroy()


if __name__ == "__main__":
    root = customtkinter.CTk()
    app = FitBuddyApp(root)
    root.mainloop()