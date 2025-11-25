# 📱 MRiverpod

A clean, modern, and fully functional **CRUD Todo Application** built using:

* **Flutter 3.x**
* **Riverpod 3.0.3 (StateNotifierProvider)**
* **Shared Preferences (local persistence)**

This project demonstrates a clean architecture, reactive state management, animations, search, filtering, and reordering—all in a single file for simplicity.

---

## ✨ Features

### ✅ Core Features

* Add todo
* Edit todo
* Delete todo
* Mark as completed
* Undo delete
* Persistent storage (SharedPreferences)

### 🎨 UI & UX

* Modern Material 3 theming
* Smooth animations
* Reorderable todo list
* Search bar
* Filter by: **All**, **Active**, **Completed**
* BottomSheet for Add/Edit

### 🧠 State Management

* `StateNotifier` + `StateNotifierProvider`
* `Ref` usage (Riverpod 3.x compatible)
* Repository pattern for persistence

---

## 🚀 Getting Started

### 1. Create a new Flutter project

```sh
flutter create todo_riverpod3
cd todo_riverpod3
```

### 2. Install dependencies

Add these lines to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.0.3
  shared_preferences: ^2.2.3
```

Then run:

```sh
flutter pub get
```

### 3. Replace `lib/main.dart` with the provided file

Copy the app from the `main.dart` file in this repo or canvas.

### 4. Run the application

```sh
flutter run
```
---

## 🧩 Key Technologies Used

* **Flutter Material 3** – modern UI
* **Riverpod 3.0.3** – state management
* **SharedPreferences** – local key/value storage
* **AnimatedList + ReorderableListView**
* **BottomSheet for CRUD dialogs**

---

## 🤝 Contributing

Feel free to suggest improvements, features, or file organization.

---

## 💬 Support / Customization

Need:

* Multi-file refactoring?
* Firebase backend?
* Hive database?
* New themes / animations?
* Desktop/Web support?

Just ask — I’ll generate it for you!
