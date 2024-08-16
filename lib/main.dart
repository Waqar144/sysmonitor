import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sysmonitor/src/rust/api/simple.dart';
import 'package:sysmonitor/src/rust/frb_generated.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

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

  Widget _createHeaderItem(String name, SortBy sorting) {
    return InkWell(
      onTap: () => updateSorting(sorting),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (sortBy == sorting && sortOrder == SortOrder.desc)
              const Icon(Icons.arrow_drop_down),
            if (sortBy == sorting && sortOrder == SortOrder.asc)
              const Icon(Icons.arrow_drop_up),
          ],
        ),
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

  String _getCpuUsage(double cpu) {
    String cpuUsage = "";
    if (cpu > 0) {
      cpuUsage = cpu.toStringAsFixed(1);
      if (cpuUsage == "0.0") cpuUsage = "";
    }
    return cpuUsage;
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    int row = vicinity.row;
    int column = vicinity.column;

    if (row == 0) {
      return TableViewCell(
        child: switch (column) {
          0 => _createHeaderItem("PID", SortBy.name),
          1 => _createHeaderItem("Name", SortBy.name),
          2 => _createHeaderItem("CPU", SortBy.cpu),
          3 => _createHeaderItem("Memory", SortBy.memory),
          _ => throw "Invalid column"
        },
      );
    }
    row = row - 1;

    return TableViewCell(
      child: switch (column) {
        0 => Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(processes[row].pid.toString()),
            ),
          ),
        1 => Align(
            alignment: Alignment.centerLeft,
            child: Text(processes[row].name),
          ),
        2 => Align(
            alignment: Alignment.centerLeft,
            child: Text(_getCpuUsage(processes[row].cpuUsage)),
          ),
        3 => Align(
            alignment: Alignment.centerLeft,
            child: Text(memoryString(processes[row].memoryUsage)),
          ),
        _ => throw "Invalid column"
      },
    );
  }

  TableSpan _buildColumnSpan(int index) {
    return switch (index % 4) {
      0 => const TableSpan(extent: FixedTableSpanExtent(100)),
      1 => const TableSpan(extent: FractionalTableSpanExtent(0.5)),
      2 => const TableSpan(extent: FixedTableSpanExtent(120)),
      3 => const TableSpan(extent: RemainingSpanExtent()),
      _ => throw AssertionError(
          'This should be unreachable, as every index is accounted for in the '
          'switch clauses.',
        ),
    };
  }

  TableSpan _buildRowSpan(int index) {
    final TableSpanDecoration decoration = TableSpanDecoration(
      color: (index > 0 && processes[index - 1].pid == selectedPid)
          ? Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5)
          : index == 0
              ? Theme.of(context).colorScheme.secondary.withOpacity(0.4)
              : null,
      border: TableSpanBorder(
        trailing: BorderSide(width: 1, color: Theme.of(context).dividerColor),
      ),
    );

    return TableSpan(
      backgroundDecoration: decoration,
      extent: const FixedTableSpanExtent(32),
      recognizerFactories: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (TapGestureRecognizer t) {
            t.onTap = () {
              if (index > 0) {
                _onRowTapped(processes[index - 1].pid);
              }
            };
          },
        ),
      },
    );
  }

  ScrollController vscroll = ScrollController();
  ScrollController hscroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // appBar: AppBar(title: const Text('')),
        body: FutureBuilder(
          future: getProcessList(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final data = snapshot.data!;
              return Scrollbar(
                controller: hscroll,
                child: Scrollbar(
                  controller: vscroll,
                  child: TableView.builder(
                    verticalDetails:
                        ScrollableDetails.vertical(controller: vscroll),
                    horizontalDetails:
                        ScrollableDetails.horizontal(controller: hscroll),
                    columnCount: 4,
                    rowCount: data.length + 1,
                    pinnedRowCount: 1,
                    rowBuilder: _buildRowSpan,
                    columnBuilder: _buildColumnSpan,
                    cellBuilder: _buildCell,
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
