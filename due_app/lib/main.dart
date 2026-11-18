import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tasks = await loadTasks() ?? seedTasks();
  runApp(DueApp(initialTasks: tasks));
}

const _seedColor = Color(0xFF6750A4);

class DueApp extends StatelessWidget {
  const DueApp({super.key, required this.initialTasks});

  final List<Task> initialTasks;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: _seedColor);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Due 当务',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22,
            height: 28 / 22,
            color: scheme.onSurface,
          ),
        ),
      ),
      home: HomePage(initialTasks: initialTasks),
    );
  }
}

/* ----------------------------- 数据模型 ----------------------------- */

enum TaskFilter { all, done, todo }

enum Importance { extreme, normal }

extension ImportanceLabel on Importance {
  String get label => this == Importance.extreme ? '极其' : '一般';
}

class Task {
  Task({
    required this.id,
    required this.name,
    required this.due,
    required this.importance,
    required this.remind,
    this.done = false,
  });

  final String id;
  final String name;
  final DateTime due;
  final Importance importance;
  final bool remind;
  bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'due': due.millisecondsSinceEpoch,
        'importance': importance.name,
        'remind': remind,
        'done': done,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        due: DateTime.fromMillisecondsSinceEpoch(json['due'] as int),
        importance: Importance.values.byName(json['importance'] as String),
        remind: json['remind'] as bool,
        done: json['done'] as bool,
      );
}

const _storageKey = 'due.tasks.v1';

Future<List<Task>?> loadTasks() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey);
  if (raw == null) return null;
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => Task.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> saveTasks(List<Task> tasks) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _storageKey,
    jsonEncode(tasks.map((t) => t.toJson()).toList()),
  );
}

List<Task> seedTasks() {
  final now = DateTime.now();
  DateTime at(int dayOffset, int hour, int minute) =>
      DateTime(now.year, now.month, now.day + dayOffset, hour, minute);

  return [
    Task(id: 't1', name: '提交 Flutter 动画作业', due: at(0, 23, 0), importance: Importance.extreme, remind: true, done: true),
    Task(id: 't2', name: '完成移动开发课程实验报告', due: at(0, 22, 0), importance: Importance.extreme, remind: true),
    Task(id: 't3', name: '背 30 个英语单词', due: at(0, 21, 0), importance: Importance.normal, remind: false),
    Task(id: 't4', name: '给妈妈打电话', due: at(0, 20, 0), importance: Importance.normal, remind: false, done: true),
    Task(id: 't5', name: '跑步 3 公里', due: at(0, 19, 30), importance: Importance.normal, remind: false),
    Task(id: 't6', name: '交社团活动报名表', due: at(1, 12, 0), importance: Importance.extreme, remind: true),
  ];
}

/* ----------------------------- 工具函数 ----------------------------- */

String two(int v) => v.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String dateStr(DateTime d) => '${d.year}/${two(d.month)}/${two(d.day)}';

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == 2) return '后天';
  return d.year == now.year ? '${d.month}月${d.day}日' : '${d.year}年${d.month}月${d.day}日';
}

String heroDate() {
  const week = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final now = DateTime.now();
  return '${now.month}月${now.day}日 · ${week[now.weekday - 1]}';
}

/* ------------------------------- 首页 ------------------------------- */

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.initialTasks});

  final List<Task> initialTasks;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final List<Task> _tasks = List.of(widget.initialTasks);
  final TextEditingController _quickCtrl = TextEditingController();
  TaskFilter _filter = TaskFilter.all;

  void _persist() {
    saveTasks(_tasks);
  }

  @override
  void dispose() {
    _quickCtrl.dispose();
    super.dispose();
  }

  List<Task> get _visible {
    final list = _tasks.where((t) {
      if (_filter == TaskFilter.done) return t.done;
      if (_filter == TaskFilter.todo) return !t.done;
      return true;
    }).toList();
    list.sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      if (byDue != 0) return byDue;
      return a.importance.index.compareTo(b.importance.index);
    });
    return list;
  }

  int get _doneCount => _tasks.where((t) => t.done).length;

  double get _progress => _tasks.isEmpty ? 0 : _doneCount / _tasks.length;

  String get _filterLabel => switch (_filter) {
        TaskFilter.all => '全部',
        TaskFilter.done => '已完成',
        TaskFilter.todo => '未完成',
      };

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2600),
      ));
  }

  void _quickAdd() {
    final name = _quickCtrl.text.trim();
    if (name.isEmpty) {
      _snack('请输入待办名称');
      return;
    }
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    setState(() {
      _tasks.add(Task(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        due: DateTime(now.year, now.month, now.day, 22, 0),
        importance: Importance.normal,
        remind: false,
      ));
      _filter = TaskFilter.all;
    });
    _persist();
    _quickCtrl.clear();
    _snack('已添加「$name」· 默认今天 22:00 / 一般');
  }

  void _toggle(Task task) {
    setState(() => task.done = !task.done);
    _persist();
  }

  Future<void> _openAdd() async {
    final created = await Navigator.of(context).push<Task>(
      MaterialPageRoute(builder: (_) => const AddPage()),
    );
    if (created == null) return;
    setState(() {
      _tasks.add(created);
      _filter = TaskFilter.all;
    });
    _persist();
    _snack('已添加「${created.name}」，截止 ${dayLabel(created.due)} ${hhmm(created.due)}');
  }

  Future<void> _openDetail(Task task) async {
    final deleted = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DetailPage(
        task: task,
        onChanged: () {
          setState(() {});
          _persist();
        },
      ),
    ));
    if (deleted == true) {
      setState(() => _tasks.remove(task));
      _persist();
      _snack('已删除「${task.name}」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '排序规则',
            onPressed: () => _snack('排序规则：截止时间越近越靠前，同一时刻重要度高的在前'),
            icon: const Icon(Icons.sort_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        onPressed: _openAdd,
        tooltip: '新增待办',
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          _progressCard(scheme),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _quickCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _quickAdd(),
                  decoration: const InputDecoration(
                    labelText: '新增待办',
                    helperText: '回车或点击“添加”即可快速创建',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _quickAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<TaskFilter>(
            segments: const [
              ButtonSegment(value: TaskFilter.all, label: Text('全部')),
              ButtonSegment(value: TaskFilter.done, label: Text('已完成')),
              ButtonSegment(value: TaskFilter.todo, label: Text('未完成')),
            ],
            selected: {_filter},
            showSelectedIcon: true,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (value) => setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('${_filter.name}-${visible.map((t) => t.id).join()}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '$_filterLabel · ${visible.length} 项',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '按截止时间 + 重要度排序',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          '这里还没有任务',
                          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else
                  ...visible.map(_taskCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 152,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/mascot.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF05B3FA8), Color(0x594F378B)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 96,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    heroDate(),
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: 0.4,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '今天也要加油鸭',
                    style: TextStyle(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '已完成 $_doneCount / ${_tasks.length} 项',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(child: _progressRing(_progress)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressRing(double value) {
    return SizedBox(
      width: 64,
      height: 64,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _RingPainter(animated),
          child: Center(
            child: Text(
              '${(animated * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskCard(Task task) {
    final scheme = Theme.of(context).colorScheme;
    final badgeColor = task.done
        ? scheme.surfaceContainerHighest
        : (task.importance == Importance.extreme
            ? scheme.errorContainer
            : scheme.primaryContainer);
    final badgeIcon = task.done
        ? scheme.onSurfaceVariant
        : (task.importance == Importance.extreme
            ? scheme.onErrorContainer
            : scheme.onPrimaryContainer);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: task.done ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetail(task),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'task-${task.id}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.flag_rounded, size: 20, color: badgeIcon),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          color: task.done ? scheme.onSurfaceVariant : scheme.onSurface,
                          decoration: task.done ? TextDecoration.lineThrough : null,
                          decorationColor: scheme.onSurfaceVariant,
                        ),
                        child: Text(
                          task.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _timeChip(task, scheme),
                          _importanceChip(task, scheme),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _toggle(task),
                  tooltip: task.done ? '标记为未完成' : '标记为已完成',
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      task.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(task.done),
                      size: 24,
                      color: task.done ? scheme.primary : scheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeChip(Task task, ColorScheme scheme) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '${dayLabel(task.due)} ${hhmm(task.due)} 前',
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _importanceChip(Task task, ColorScheme scheme) {
    final Color background;
    final Color foreground;
    if (task.done) {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    } else if (task.importance == Importance.extreme) {
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
    } else {
      background = scheme.secondaryContainer;
      foreground = scheme.onSecondaryContainer;
    }

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            task.importance.label,
            style: TextStyle(fontSize: 12, height: 16 / 12, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

/* ------------------------------ 详情页 ------------------------------ */

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.task, required this.onChanged});

  final Task task;
  final VoidCallback onChanged;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  void _toggle() {
    setState(() => widget.task.done = !widget.task.done);
    widget.onChanged();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除待办？'),
        content: Text('「${widget.task.name}」删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final scheme = Theme.of(context).colorScheme;
    final badgeColor = task.done
        ? scheme.surfaceContainerHighest
        : (task.importance == Importance.extreme
            ? scheme.errorContainer
            : scheme.primaryContainer);
    final badgeIcon = task.done
        ? scheme.onSurfaceVariant
        : (task.importance == Importance.extreme
            ? scheme.onErrorContainer
            : scheme.onPrimaryContainer);

    return Scaffold(
      appBar: AppBar(title: const Text('待办详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'task-${task.id}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.flag_rounded, size: 48, color: badgeIcon),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: TextStyle(
                        fontSize: 22,
                        height: 28 / 22,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${dayLabel(task.due)}截止 · ${task.done ? '已完成' : '未完成'}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _infoRow(
                  context,
                  '截止时间',
                  '${dateStr(task.due)} ${hhmm(task.due)}（${dayLabel(task.due)}）',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Text('重要度', style: _valueStyle(scheme)),
                      const Spacer(),
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: task.importance == Importance.extreme
                              ? scheme.errorContainer
                              : scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          task.importance.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: task.importance == Importance.extreme
                                ? scheme.onErrorContainer
                                : scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _infoRow(context, '提醒', task.remind ? '已开启' : '已关闭'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _infoRow(context, '状态', task.done ? '已完成' : '未完成'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _toggle,
              child: Text(task.done ? '标记为未完成' : '标记为已完成'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除待办'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _valueStyle(ColorScheme scheme) => TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: scheme.onSurface,
      );

  Widget _infoRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: _valueStyle(scheme)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ 新增页 ------------------------------ */

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  late DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 22, minute: 0);
  Importance _importance = Importance.normal;
  bool _remind = false;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: '选择截止日期',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '选择截止时间',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    setState(() => _nameError = name.isEmpty ? '请输入待办名称' : null);
    if (_nameError != null) return;

    final due = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    Navigator.of(context).pop(Task(
      id: 't${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      due: due,
      importance: _importance,
      remind: _remind,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('新增待办')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '名称',
              helperText: '为待办取一个清晰的名称',
              errorText: _nameError,
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 115, child: _dateField(scheme)),
              const SizedBox(width: 8),
              Expanded(flex: 100, child: _timeField(scheme)),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Importance>(
            initialValue: _importance,
            decoration: const InputDecoration(
              labelText: '重要度',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: Importance.extreme, child: Text('极其')),
              DropdownMenuItem(value: Importance.normal, child: Text('一般')),
            ],
            onChanged: (value) =>
                setState(() => _importance = value ?? Importance.normal),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text('是否开启提醒'),
              subtitle: Text('当前：${_remind ? '是' : '否'}'),
              value: _remind,
              onChanged: (value) => setState(() => _remind = value),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '保存后按截止时间与重要度自动排序',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(ColorScheme scheme) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '截止日期',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          '${_date.year}/${two(_date.month)}/${two(_date.day)}',
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
        ),
      ),
    );
  }

  Widget _timeField(ColorScheme scheme) {
    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '截止时间',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.schedule, size: 18),
        ),
        child: Text(
          '${two(_time.hour)}:${two(_time.minute)}',
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
        ),
      ),
    );
  }
}
