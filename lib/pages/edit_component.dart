import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logic_circuits_simulator/models/project.dart';
import 'package:logic_circuits_simulator/state/project.dart';
import 'package:logic_circuits_simulator/utils/iterable_extension.dart';
import 'package:logic_circuits_simulator/utils/provider_hook.dart';

class EditComponentPage extends HookWidget {
  final bool newComponent;
  final ComponentEntry component;

  const EditComponentPage({Key? key, this.newComponent = false, required this.component}) : super(key: key);

  static const String routeName = '/project/component/edit';

  @override
  Widget build(BuildContext context) {
    final anySave = useState(false);
    final projectState = useProvider<ProjectState>();
    final ce = projectState.index.components.where((c) => c.componentId == component.componentId).first;
    final truthTable = useState(ce.truthTable?.toList());
    final inputs = useState(ce.inputs.toList());
    final outputs = useState(ce.outputs.toList());
    final componentNameEditingController = useTextEditingController(text: ce.componentName);
    useValueListenable(componentNameEditingController);
    final dirty = useMemoized(
      () {
        if (componentNameEditingController.text.isEmpty) {
          // Don't allow saving empty name
          return false;
        }
        if (inputs.value.isEmpty) {
          // Don't allow saving empty inputs
          return false;
        }
        if (outputs.value.isEmpty) {
          // Don't allow saving empty outputs
          return false;
        }
        if (componentNameEditingController.text != ce.componentName) {
          return true;
        }
        if (!const ListEquality().equals(inputs.value, ce.inputs)) {
          return true;
        }
        if (!const ListEquality().equals(outputs.value, ce.outputs)) {
          return true;
        }
        if (!const ListEquality().equals(truthTable.value, ce.truthTable)) {
          return true;
        }
        return false;
      },
      [
        componentNameEditingController.text,
        ce.componentName,
        inputs.value,
        ce.inputs,
        outputs.value,
        ce.outputs,
        truthTable.value,
        ce.truthTable,
      ],
    );

    return WillPopScope(
      onWillPop: () async {
        if (!dirty && !newComponent) {
          Navigator.of(context).pop(true);
        } else if (!dirty && anySave.value) {
          Navigator.of(context).pop(true);
        } else {
          final dialogResult = await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.red),
                    ),
                    child: const Text('Discard'),
                  ),
                ],
                title: Text('Cancel ${newComponent ? 'Creation' : 'Editing'}'),
                content: Text(newComponent ? 'A new component will not be created.' : 'Are you sure you want to discard the changes?'),
              );
            }
          );
          if (dialogResult == true) {
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop(!newComponent);
          }
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(newComponent ? 'New Component' : 'Edit Component'),
          centerTitle: true,
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: componentNameEditingController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Component name',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Inputs',
                  style: Theme.of(context).textTheme.headline5,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => ListTile(
                  title: Text(ce.inputs[i]),
                ),
                childCount: ce.inputs.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Outputs',
                  style: Theme.of(context).textTheme.headline5,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => ListTile(
                  title: Text(ce.outputs[i]),
                ),
                childCount: ce.outputs.length,
              ),
            ),
            if (truthTable.value != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Truth Table',
                    style: Theme.of(context).textTheme.headline5,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TruthTableEditor(
                    truthTable: truthTable.value!,
                    inputs: inputs.value,
                    outputs: outputs.value,
                    onUpdateTable: (idx, newValue) {
                      truthTable.value = truthTable.value?.toList()?..replaceRange(idx, idx+1, [newValue]);
                    },
                  ),
                ),
              )
            ],
          ],
        ),
        floatingActionButton: !dirty ? null : FloatingActionButton(
          onPressed: () async {
            if (componentNameEditingController.text.isNotEmpty) {
              await projectState.editComponent(component.copyWith(componentName: componentNameEditingController.text));
            }
            await projectState.editComponent(ce.copyWith(
              inputs: inputs.value,
              outputs: outputs.value,
              truthTable: truthTable.value,
            ));
            anySave.value = true;
            // TODO: Implement saving
          },
          tooltip: 'Save Component',
          child: const Icon(Icons.save),
        ),
      ),
    );
  }
}

class TruthTableHeaderText extends StatelessWidget {
  final String text;
  final BoxBorder? border;

  const TruthTableHeaderText(this.text, {super.key, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: border,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
    );
  }
}

class TruthTableTrue extends StatelessWidget {
  final BoxBorder? border;
  final void Function()? onTap;

  const TruthTableTrue({super.key, this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: border,
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          'T',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: Colors.green,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class TruthTableFalse extends StatelessWidget {
  final BoxBorder? border;
  final void Function()? onTap;

  const TruthTableFalse({super.key, this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: border,
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          'F',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: Colors.red,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class TruthTableEditor extends StatelessWidget {
  final List<String> inputs;
  final List<String> outputs;
  final List<String> truthTable;

  final void Function(int, String) onUpdateTable;

  const TruthTableEditor({Key? key, required this.inputs, required this.outputs, required this.truthTable, required this.onUpdateTable}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.symmetric(outside: const BorderSide(width: 2)),
      children: List.generate(
        truthTable.length + 1, 
        (index) {
          if (index == 0) {
            return TableRow(
              children: inputs
                .indexedMap<Widget>(
                  (index, e) => TruthTableHeaderText(
                    e,
                    border: Border(
                      bottom: const BorderSide(width: 2),
                      right: index == inputs.length - 1 ? const BorderSide(width: 2) : BorderSide.none,
                    ),
                  )
                )
                .followedBy(
                  outputs
                  .map((e) => TruthTableHeaderText(e, border: const Border(bottom: BorderSide(width: 2)),))
                )
                .toList(),
            );
          }
          final inputBinary = (index - 1).toRadixString(2).padLeft(inputs.length, '0');
          final outputBinary = truthTable[index - 1];

          Widget runeToWidget({required int rune, void Function()? onTap, BoxBorder? border}) {
            return int.parse(String.fromCharCode(rune)) != 0 
              ? TruthTableTrue(
                border: border,
                onTap: onTap,
              ) 
              : TruthTableFalse(
                border: border,
                onTap: onTap,
              );
          }

          return TableRow(
            children: inputBinary.runes.indexedMap(
                (i, r) => runeToWidget(
                  rune: r, 
                  border: i == inputBinary.runes.length - 1 ? const Border(right: BorderSide(width: 2)) : null,
                )
              )
              .followedBy(outputBinary.runes.indexedMap(
                (i, r) => runeToWidget(
                  rune: r,
                  onTap: () {
                    onUpdateTable(index - 1, outputBinary.replaceRange(i, i+1, (outputBinary[i] == "1") ? "0" : "1"));
                  },
                ),
              ))
              .toList(),
          );
        },
      ),
    );
  }
}
