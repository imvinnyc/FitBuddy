# FitBuddy

FitBuddy is a comprehensive fitness application designed to help users track their nutrition, calculate daily calorie needs, log workouts, build personalized workout plans, and generate healthy diet plans. Built with Python and CustomTkinter, FitBuddy offers an intuitive GUI experience for users aiming to achieve their fitness goals.

## Features

### Nutrition Tracker
- Log daily nutrient intake including calories, fat, protein, carbohydrates, and fiber.
- View and visualize nutrition logs with graphs and charts.
- Clear entries for specific dates or the entire log.

### Calorie Calculator
- Calculate daily calorie needs based on age, gender, height, weight, and activity level.
- Provides a quick estimation to help plan meals and workouts.

### Workout Tracker
- Record workout details such as workout type, exercises, sets, and reps.
- View workout logs and visualize progress over time.
- Clear workout entries for specific dates or the entire log.

### Workout Builder
- Generate personalized workout plans based on goals, intensity, duration, body type, dietary preference, and fitness level.
- Save and view generated workout plans for future reference.
- Integrates with a backend server to fetch customized workout routines.

### Diet Generator
- Create healthy diet plans tailored to dietary preferences, goals, and body types.
- Save and view generated diet plans.
- Utilizes a backend server to generate personalized diet recommendations.

## Libraries Used

- **tkinter**: Standard Python interface for creating GUI applications.
- **customtkinter**: A modern and customizable UI framework for tkinter.
- **matplotlib**: Library for creating static, animated, and interactive visualizations.
- **requests**: Simplifies HTTP requests to communicate with the backend server.
- **json**: For reading and writing JSON files to store logs and saved plans.
- **datetime**: To handle date and time operations.
- **threading**: Enables asynchronous API calls without freezing the GUI.
- **os** and **sys**: For system-level operations like setting window icons.

## Installation

### Prerequisites

- Python 3.x installed on your system.
- pip (Python package installer).

### Steps

- **Clone the Repository**
```
git clone https://github.com/imvinnyc/FitBuddy.git
```
- **Navigate to the Project Directory**
```
cd FitBuddy
```
- **Create a Virtual Environment (Optional) (Recommended)**
```
python -m venv venv # To create the virtual environment
venv\Scripts\activate # To activate the virtual environment on Windows
source venv/bin/activate # To activate the virtual environment on Mac/Linux
```
- **Install Required Libraries**
```
pip install -r requirements.txt
```
- **Run the Application**
```
python main.py
```

## Development Status

FitBuddy is currently under development for bug testing and enhancing user experience. While all primary features are implemented and functional, ongoing work focuses on improving the application's intuitiveness and performance.

## Backend Server

FitBuddy integrates with a backend server that securely manages APIs and generates personalized workout and diet plans using OpenAI's Python library. To explore the backend server, visit the repository:

[GitHub: FitBuddy Backend Server](https://github.com/imvinnyc/fitbuddy_backend)

---

Thank you for using FitBuddy! Your journey to a healthier lifestyle starts here.
