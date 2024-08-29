import 'package:flutter/material.dart';
import 'package:sysmonitor/src/rust/api/simple.dart';

import 'utils.dart';

class ProcessDetailsDialog extends StatelessWidget {
  final ProcessDetails details;
  final String processName;

  const ProcessDetailsDialog(this.processName, this.details, {super.key});

  Widget row(String key, String value) {
    return Row(
      children: [
        Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(processName),
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text("Close"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        )
      ],
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SelectionArea(
          child: ListView(
            children: [
              row("Command: ", details.cmd),
              const Divider(height: 1),
              row("Working Directory: ", details.cwd),
              const Divider(height: 1),
              row("Total Disk Read: ", memoryString(details.diskRead)),
              const Divider(height: 1),
              row("Total Disk Write: ", memoryString(details.diskWrite)),
              const Divider(height: 1),
              row("Virtual Memory: ", memoryString(details.virtualMemory)),
              const Divider(height: 1),
              const Text("Environment: ",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: details.env.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(details.env[index],
                        style: const TextStyle(fontSize: 14)),
                    minVerticalPadding: 0,
                    minTileHeight: 14,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
