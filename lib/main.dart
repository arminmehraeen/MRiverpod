import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------
// MODEL
// ---------------------------------------------------------
class Todo {
  final String id;
  final String title;
  final String? description;
  final bool completed;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.description,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Todo.fromMap(Map<String, dynamic> m) => Todo(
    id: m['id'],
    title: m['title'],
    description: m['description'],
    completed: m['completed'],
    createdAt: DateTime.parse(m['createdAt']),
  );
}

// ---------------------------------------------------------
// REPOSITORY (LOCAL PERSISTENCE)
// ---------------------------------------------------------
class TodoRepository {
  static const storageKey = 'TODOS';
  final SharedPreferences prefs;

  TodoRepository(this.prefs);

  List<Todo> load() {
    final text = prefs.getString(storageKey);
    if (text == null) return [];
    final list = jsonDecode(text) as List;
    return list.map((e) => Todo.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> save(List<Todo> items) async {
    await prefs.setString(
      storageKey,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
  }
}

// Providers
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository(ref.watch(sharedPrefsProvider));
});

// ---------------------------------------------------------
// STATE NOTIFIER (Riverpod 3)
// ---------------------------------------------------------
class TodoListNotifier extends StateNotifier<List<Todo>> {
  final Ref ref;
  TodoListNotifier(this.ref) : super([]) {
    _load();
  }

  void _load() {
    state = ref.read(todoRepositoryProvider).load();
  }

  Future<void> _save() async => ref.read(todoRepositoryProvider).save(state);

  Future<void> add(String title, String? description) async {
    final item = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      description: description?.trim().isEmpty == true ? null : description,
    );
    state = [item, ...state];
    await _save();
  }

  Future<void> update(Todo todo) async {
    state = [for (final t in state) if (t.id == todo.id) todo else t];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  Future<void> toggle(String id) async {
    final t = state.firstWhere((e) => e.id == id);
    update(t.copyWith(completed: !t.completed));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _save();
  }
}

final todoListProvider = StateNotifierProvider<TodoListNotifier, List<Todo>>(
      (ref) => TodoListNotifier(ref),
);

// Filters
enum TodoFilter { all, active, completed }
final filterProvider = StateProvider<TodoFilter>((ref) => TodoFilter.all);
final searchProvider = StateProvider<String>((ref) => "");

final filteredTodosProvider = Provider<List<Todo>>((ref) {
  final list = ref.watch(todoListProvider);
  final filter = ref.watch(filterProvider);
  final query = ref.watch(searchProvider).toLowerCase();

  return list.where((t) {
    if (filter == TodoFilter.active && t.completed) return false;
    if (filter == TodoFilter.completed && !t.completed) return false;
    if (query.isNotEmpty && !t.title.toLowerCase().contains(query)) return false;
    return true;
  }).toList();
});

// ---------------------------------------------------------
// MAIN + UI
// ---------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const TodoApp(),
    ),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const TodoHomePage(),
    );
  }
}

class TodoHomePage extends ConsumerWidget {
  const TodoHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(filteredTodosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Todo App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(context: context, delegate: TodoSearchDelegate(ref)),
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => _showFilterSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        label: const Text("Add Todo"),
        icon: const Icon(Icons.add),
      ),
      body: todos.isEmpty
          ? const Center(child: Text("No todos yet."))
          : ReorderableListView.builder(
        itemCount: todos.length,
        onReorder: (oldIndex, newIndex) => ref.read(todoListProvider.notifier).reorder(oldIndex, newIndex),
        itemBuilder: (context, i) {
          final t = todos[i];
          return Dismissible(
            key: ValueKey(t.id),
            onDismissed: (_) => ref.read(todoListProvider.notifier).remove(t.id),
            background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
            child: ListTile(
              leading: const Icon(Icons.drag_handle),
              title: Text(t.title, style: TextStyle(decoration: t.completed ? TextDecoration.lineThrough : null)),
              subtitle: t.description == null ? null : Text(t.description!),
              trailing: Checkbox(
                value: t.completed,
                onChanged: (_) => ref.read(todoListProvider.notifier).toggle(t.id),
              ),
              onTap: () => _openForm(context, ref, todo: t),
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final filter = ref.watch(filterProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("All"),
              trailing: filter == TodoFilter.all ? const Icon(Icons.check) : null,
              onTap: () => ref.read(filterProvider.notifier).state = TodoFilter.all,
            ),
            ListTile(
              title: const Text("Active"),
              trailing: filter == TodoFilter.active ? const Icon(Icons.check) : null,
              onTap: () => ref.read(filterProvider.notifier).state = TodoFilter.active,
            ),
            ListTile(
              title: const Text("Completed"),
              trailing: filter == TodoFilter.completed ? const Icon(Icons.check) : null,
              onTap: () => ref.read(filterProvider.notifier).state = TodoFilter.completed,
            ),
          ],
        );
      }),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Todo? todo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TodoForm(todo: todo),
    );
  }
}

// ---------------------------------------------------------
// FORM
// ---------------------------------------------------------
class TodoForm extends ConsumerStatefulWidget {
  final Todo? todo;
  const TodoForm({super.key, this.todo});

  @override
  ConsumerState<TodoForm> createState() => _TodoFormState();
}

class _TodoFormState extends ConsumerState<TodoForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController title;
  late TextEditingController desc;
  bool completed = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.todo?.title ?? "");
    desc = TextEditingController(text: widget.todo?.description ?? "");
    completed = widget.todo?.completed ?? false;
  }

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.todo != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? "Edit Todo" : "New Todo", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Enter title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: desc,
                decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                maxLines: 3,
              ),
              if (isEdit) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  value: completed,
                  onChanged: (v) => setState(() => completed = v),
                  title: const Text("Completed"),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  if (widget.todo == null) {
                    await ref.read(todoListProvider.notifier).add(title.text, desc.text);
                  } else {
                    await ref.read(todoListProvider.notifier).update(
                      widget.todo!.copyWith(
                        title: title.text,
                        description: desc.text,
                        completed: completed,
                      ),
                    );
                  }

                  if (mounted) Navigator.pop(context);
                },
                child: Text(isEdit ? "Save" : "Create"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SEARCH
// ---------------------------------------------------------
class TodoSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  TodoSearchDelegate(this.ref) : super(searchFieldLabel: "Search todos");

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = "", icon: const Icon(Icons.clear)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    final items = ref.read(todoListProvider);
    final results = items.where((t) => t.title.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) {
        final t = results[i];
        return ListTile(
          title: Text(t.title),
          subtitle: t.description == null ? null : Text(t.description!),
          onTap: () => close(context, t),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final items = ref.read(todoListProvider);
    final results = items.where((t) => t.title.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(results[i].title),
        onTap: () {
          query = results[i].title;
          showResults(context);
        },
      ),
    );
  }
}