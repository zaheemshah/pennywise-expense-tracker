
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


const navy = Color(0xFF080D12);
const panel = Color(0xFF111A20);
const panelLight = Color(0xFF24332F);
const accent = Color(0xFFB7F36B);
const incomeColor = Color(0xFFB7F36B);
const expenseColor = Color(0xFFFF7185);
const muted = Color(0xFF9AA9A5);


const categories = [
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Salary',
  'Freelance',
  'Other',
];

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: panel,
          onPrimary: navy,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: panelLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accent),
          ),
        ),
      ),
      home: const ExpenseHomePage(),
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  static const storageKey = 'expense_transactions';
  static const budgetKey = 'expense_monthly_budget';

  List<Map<String, dynamic>> transactions = [];
  bool loading = true;
  int selectedTab = 0;

  double monthlyBudget = 0;
  String search = '';
  String typeFilter = 'All';
  String categoryFilter = 'All';
  DateTime reportMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    List<Map<String, dynamic>> loaded = [];

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        loaded = decoded.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          map['title'] = (map['title'] ?? '').toString();
          map['amount'] = (map['amount'] as num?)?.toDouble() ?? 0.0;
          map['income'] = map['income'] == true;
          map['category'] = (map['category'] ?? 'Other').toString();
          map['date'] = (map['date'] ?? DateTime.now().toIso8601String())
              .toString();
          return map;
        }).toList();
      } catch (_) {
        loaded = [];
      }
    }

    if (!mounted) return;
    setState(() {
      transactions = loaded;
      monthlyBudget = prefs.getDouble(budgetKey) ?? 0;
      loading = false;
    });
  }

  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(transactions));
  }

  Future<void> saveBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(budgetKey, value);
    if (!mounted) return;
    setState(() => monthlyBudget = value);
  }

  double get totalIncome => transactions
      .where((t) => t['income'] == true)
      .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

  double get totalExpenses => transactions
      .where((t) => t['income'] != true)
      .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

  double get balance => totalIncome - totalExpenses;

  bool sameMonth(Map<String, dynamic> t, DateTime month) {
    final date = DateTime.tryParse(t['date'].toString()) ?? DateTime.now();
    return date.year == month.year && date.month == month.month;
  }

  List<Map<String, dynamic>> get monthTransactions =>
      transactions.where((t) => sameMonth(t, reportMonth)).toList();

  double get monthIncome => monthTransactions
      .where((t) => t['income'] == true)
      .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

  double get monthExpenses => monthTransactions
      .where((t) => t['income'] != true)
      .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

  List<Map<String, dynamic>> get filteredTransactions {
    final list = transactions.where((t) {
      final title = t['title'].toString().toLowerCase();
      final category = t['category'].toString();
      final matchesSearch = title.contains(search.toLowerCase()) ||
          category.toLowerCase().contains(search.toLowerCase());

      final matchesType = typeFilter == 'All' ||
          (typeFilter == 'Income' && t['income'] == true) ||
          (typeFilter == 'Expense' && t['income'] != true);

      final matchesCategory =
          categoryFilter == 'All' || category == categoryFilter;

      return matchesSearch && matchesType && matchesCategory;
    }).toList();

    list.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    return list;
  }

  String money(num amount) => 'Rs ${amount.toStringAsFixed(2)}';

  String dateLabel(String value) {
    final date = DateTime.tryParse(value) ?? DateTime.now();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> openTransactionDialog({
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
    TextEditingController(text: existing?['title']?.toString() ?? '');
    final amountController = TextEditingController(
      text: existing == null
          ? ''
          : (existing['amount'] as num).toString(),
    );

    bool isIncome = existing?['income'] == true;
    String category = existing?['category']?.toString() ?? 'Food';
    DateTime date =
        DateTime.tryParse(existing?['date']?.toString() ?? '') ?? DateTime.now();

    if (!categories.contains(category)) category = 'Other';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: panel,
          title: Text(existing == null ? 'Add transaction' : 'Edit transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (Rs)'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isIncome ? 'Income' : 'Expense'),
                  value: isIncome,
                  activeThumbColor: accent,
                  onChanged: (value) =>
                      setDialogState(() => isIncome = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(category) ? category : 'Other',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) => Theme(
                        data: Theme.of(context),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() => date = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(dateLabel(date.toIso8601String())),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim());

                if (title.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a title and a valid amount.'),
                    ),
                  );
                  return;
                }

                final record = <String, dynamic>{
                  'title': title,
                  'amount': amount,
                  'income': isIncome,
                  'category': category,
                  'date': date.toIso8601String(),
                };

                setState(() {
                  if (existing == null) {
                    transactions.add(record);
                  } else {
                    final index = transactions.indexOf(existing);
                    if (index >= 0) transactions[index] = record;
                  }
                });

                await saveTransactions();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(existing == null ? 'Add' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    amountController.dispose();
  }

  Future<void> deleteTransaction(Map<String, dynamic> transaction) async {
    setState(() => transactions.remove(transaction));
    await saveTransactions();
  }

  Future<void> exportCsv() async {
    final rows = <List<String>>[
      ['Title', 'Amount', 'Type', 'Category', 'Date'],
      ...transactions.map((t) => [
        t['title'].toString(),
        (t['amount'] as num).toStringAsFixed(2),
        t['income'] == true ? 'Income' : 'Expense',
        t['category'].toString(),
        dateLabel(t['date'].toString()),
      ]),
    ];

    String escape(String value) => '"${value.replaceAll('"', '""')}"';
    final csv = rows.map((row) => row.map(escape).join(',')).join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied! Paste it into Excel or Google Sheets.'),
      ),
    );
  }

  Future<void> editBudgetDialog() async {
    final controller = TextEditingController(
      text: monthlyBudget == 0 ? '' : monthlyBudget.toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Monthly budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Budget in Rs',
            hintText: 'e.g. 30000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount < 0) return;
              await saveBudget(amount);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save budget'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void changeMonth(int amount) {
    setState(() {
      reportMonth = DateTime(reportMonth.year, reportMonth.month + amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHome(),
      buildReports(),
      buildSettings(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet, color: accent),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PennyWise',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('PERSONAL FINANCE',
                    style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: pages,
        ),
      ),
      floatingActionButton: selectedTab == 0
          ? FloatingActionButton.extended(
        onPressed: () => openTransactionDialog(),
        backgroundColor: accent,
        foregroundColor: navy,
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        backgroundColor: panel,
        indicatorColor: accent.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget buildHome() {
    final budgetUsed = monthlyBudget > 0 ? monthExpenses / monthlyBudget : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text('Your money, in focus',
            style: TextStyle(color: muted, fontSize: 14)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF233B5D), Color(0xFF17243B), Color(0xFF151D31)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: accent),
                  SizedBox(width: 8),
                  Text('TOTAL BALANCE', style: TextStyle(color: muted, letterSpacing: 1.4, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Text(money(balance),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: miniMetric('Income', totalIncome, incomeColor, Icons.south_west)),
                  const SizedBox(width: 12),
                  Expanded(child: miniMetric('Expenses', totalExpenses, expenseColor, Icons.north_east)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (monthlyBudget > 0) ...[
          sectionTitle('Monthly budget', trailing: Text(money(monthlyBudget), style: const TextStyle(color: muted))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('This month spent'),
                    Text(money(monthExpenses), style: TextStyle(color: budgetUsed >= 1 ? expenseColor : accent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: budgetUsed.clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: panelLight,
                    color: budgetUsed >= 1 ? expenseColor : accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  budgetUsed >= 1
                      ? 'Budget reached or exceeded!'
                      : '${(budgetUsed * 100).toStringAsFixed(0)}% of your monthly budget used',
                  style: TextStyle(color: budgetUsed >= 1 ? expenseColor : muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        sectionTitle('Transactions', trailing: Text('${filteredTransactions.length} total', style: const TextStyle(color: muted))),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            hintText: 'Search transactions...',
            prefixIcon: Icon(Icons.search, color: muted),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: typeFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['All', 'Income', 'Expense']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => typeFilter = v ?? 'All'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: categoryFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['All', ...categories]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => categoryFilter = v ?? 'All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredTransactions.isEmpty)
          emptyState('No transactions found', 'Add a transaction or change your filters.')
        else
          ...filteredTransactions.map(transactionTile),
      ],
    );
  }

  Widget buildReports() {
    final spending = <String, double>{};

    for (final t in monthTransactions.where((t) => t['income'] != true)) {
      final category = t['category'].toString();
      spending[category] =
          (spending[category] ?? 0) + (t['amount'] as num).toDouble();
    }

    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highest = sorted.isEmpty ? 1.0 : sorted.first.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Monthly insights',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Understand where your money goes.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 18),
        Container(
          decoration: panelDecoration(),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_monthName(reportMonth.month)} ${reportMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: () => changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: summaryCard('Income', monthIncome, incomeColor, Icons.south_west)),
            const SizedBox(width: 10),
            Expanded(child: summaryCard('Expenses', monthExpenses, expenseColor, Icons.north_east)),
          ],
        ),
        const SizedBox(height: 12),
        summaryCard(
          'Net savings',
          monthIncome - monthExpenses,
          monthIncome - monthExpenses >= 0 ? accent : expenseColor,
          Icons.savings_outlined,
        ),
        const SizedBox(height: 22),
        sectionTitle('Spending by category'),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          emptyState('Nothing to report yet', 'Add expenses to see category breakdown.')
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: panelDecoration(),
            child: Column(
              children: sorted.map((entry) {
                final ratio = (entry.value / highest).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(money(entry.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          color: accent,
                          backgroundColor: panelLight,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: exportCsv,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export transactions as CSV'),
        ),
      ],
    );
  }

  Widget buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Make the tracker work for you.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.savings_outlined, color: accent, size: 28),
              const SizedBox(height: 12),
              const Text('Monthly budget',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                monthlyBudget > 0 ? money(monthlyBudget) : 'No budget set',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: editBudgetDialog,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Set or edit budget'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        settingsTile(
          Icons.file_download_outlined,
          'Export CSV',
          'Copy transaction data for Excel or Sheets',
          exportCsv,
        ),
        settingsTile(
          Icons.info_outline,
          'About PennyWise',
          'Personal finance and expense tracking',
              () => showAboutDialog(
            context: context,
            applicationName: 'PennyWise Expense Tracker',
            applicationVersion: '1.0.0',
            applicationLegalese: 'Track your money with clarity.',
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('PennyWise • Your finances, simplified',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12)),
        ),
      ],
    );
  }

  Widget transactionTile(Map<String, dynamic> t) {
    final isIncome = t['income'] == true;
    final color = isIncome ? incomeColor : expenseColor;
    final amount = (t['amount'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: panelDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(categoryIcon(t['category'].toString()), color: color),
        ),
        title: Text(t['title'].toString(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${t['category']} • ${dateLabel(t['date'].toString())}',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        trailing: SizedBox(
          width: 124,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '${isIncome ? '+' : '-'}${money(amount)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, color: muted),
                onSelected: (value) {
                  if (value == 'edit') openTransactionDialog(existing: t);
                  if (value == 'delete') confirmDelete(t);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> confirmDelete(Map<String, dynamic> t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Delete transaction?'),
        content: Text('Remove "${t['title']}" from your transactions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await deleteTransaction(t);
  }

  Widget miniMetric(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 7),
          Text(money(amount),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget summaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: muted)),
          const SizedBox(height: 5),
          Text(money(amount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ?trailing,
      ],
    );
  }

  Widget emptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: panelDecoration(),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 38, color: muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget settingsTile(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: panelDecoration(),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: accent),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(color: muted)),
        trailing: const Icon(Icons.chevron_right, color: muted),
      ),
    );
  }

  BoxDecoration panelDecoration() => BoxDecoration(
    color: panel,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
  );

  IconData categoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Bills':
        return Icons.receipt_long_outlined;
      case 'Health':
        return Icons.favorite_border;
      case 'Entertainment':
        return Icons.movie_outlined;
      case 'Salary':
        return Icons.work_outline;
      case 'Freelance':
        return Icons.laptop_mac;
      default:
        return Icons.payments_outlined;
    }
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}
