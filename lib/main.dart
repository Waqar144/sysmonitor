import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sysmonitor/src/rust/api/simple.dart';
import 'package:sysmonitor/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late Timer t;
  MySystem? sys;
  List<MyProcess> processes = [];
  BigInt selectedPid = BigInt.from(0);
  bool reloadProcesses = false;
  SortBy sortBy = SortBy.cpu;
  SortOrder sortOrder = SortOrder.desc;

  @override
  void initState() {
    super.initState();
    reloadProcesses = true;
    t = Timer(const Duration(seconds: 1), () {});
  }

  void refresh() {
    setState(() {
      reloadProcesses = true;
    });
  }

  void _onRowTapped(BigInt pid) {
    setState(() {
      selectedPid = pid;
    });
  }

  Future<List<MyProcess>> getProcessList() async {
    if (!reloadProcesses) {
      return processes;
    }

    t.cancel();
    t = Timer(const Duration(seconds: 2), refresh);

    sys ??= await MySystem.newAll();

    processes = await sys!.processes(sorting: sortBy, sortOrder: sortOrder);

    reloadProcesses = false;
    return processes;
  }

  void updateSorting(SortBy newSortBy) {
    final old = sortBy;
    sortBy = newSortBy;
    if (newSortBy == old) {
      if (sortOrder == SortOrder.asc) {
        sortOrder = SortOrder.desc;
      } else if (sortOrder == SortOrder.desc) {
        sortOrder = SortOrder.asc;
      }
    }
    refresh();
  }

  DataColumn _createDataColumn(String name, SortBy sorting) {
    return DataColumn(
      onSort: (columnIndex, ascending) {
        updateSorting(sorting);
      },
      label: Row(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (sortBy == sorting && sortOrder == SortOrder.desc)
            const Icon(Icons.arrow_drop_down),
          if (sortBy == sorting && sortOrder == SortOrder.asc)
            const Icon(Icons.arrow_drop_up),
        ],
      ),
    );
  }

  String memoryString(BigInt memory) {
    // ignore: constant_identifier_names
    const int GB = 1024 * 1024 * 1024;
    // ignore: constant_identifier_names
    const int MB = 1024 * 1024;
    // ignore: constant_identifier_names
    const int KB = 1024;
    if (memory.toInt() > GB) {
      return "${(memory.toInt() / GB).toStringAsFixed(1)}G";
    } else if (memory.toInt() > MB) {
      return "${(memory.toInt() / MB).toStringAsFixed(1)}M";
    } else {
      return "${(memory.toInt() / KB).toStringAsFixed(1)}K";
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('')),
        body: FutureBuilder(
          future: getProcessList(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final data = snapshot.data!;
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: double.infinity),
                  child: DataTable(
                    dataRowMaxHeight: 32,
                    dataRowMinHeight: 24,
                    headingRowHeight: 32,
                    headingRowColor: const WidgetStatePropertyAll(Colors.grey),
                    columns: [
                      _createDataColumn("Pid", SortBy.pid),
                      _createDataColumn("Name", SortBy.name),
                      _createDataColumn("CPU", SortBy.cpu),
                      _createDataColumn("Memory", SortBy.memory),
                    ],
                    rows: data.map((p) {
                      String cpuUsage = "";
                      if (p.cpuUsage > 0) {
                        cpuUsage = p.cpuUsage.toStringAsFixed(1);
                        if (cpuUsage == "0.0") cpuUsage = "";
                      }
                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Theme.of(context)
                                .colorScheme
                                .inversePrimary
                                .withOpacity(0.5);
                          }
                          return null; // Use the default value.
                        }),
                        selected: p.pid == selectedPid,
                        cells: [
                          DataCell(
                            onTap: () => _onRowTapped(p.pid),
                            Text(p.pid.toString()),
                          ),
                          DataCell(
                            onTap: () => _onRowTapped(p.pid),
                            Text(p.name),
                          ),
                          DataCell(
                            onTap: () => _onRowTapped(p.pid),
                            Text(cpuUsage),
                          ),
                          DataCell(
                            onTap: () => _onRowTapped(p.pid),
                            Text(memoryString(p.memoryUsage)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            return const Center(child: Text("Loading"));
          },
        ),
      ),
    );
  }
}
