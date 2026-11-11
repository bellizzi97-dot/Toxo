import 'package:flutter/material.dart';

import '../data/knowledge_database.dart';
import 'feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.database, super.key});

  final KnowledgeDatabase database;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _addMemory() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir preferencia'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Por ejemplo: prefiero respuestas breves',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    try {
      widget.database.remember(note);
      setState(() {});
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ?? 'Preferencia no válida.',
          ),
        ),
      );
    }
  }

  Future<void> _clearMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar preferencias'),
        content: const Text('Se eliminarán todas las preferencias guardadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.database.clearMemories();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.database.memoryEnabled;
    final memories = widget.database.memories;
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias y privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Memoria local'),
              subtitle: const Text(
                'Guarda solo preferencias que escribas aquí. Todo queda en este dispositivo.',
              ),
              value: enabled,
              onChanged: (value) {
                widget.database.setMemoryEnabled(value);
                setState(() {});
              },
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Probar IA por internet'),
              subtitle: const Text(
                'Solo se enviará una pregunta cuando pulses “Preguntar a IA”. '
                'No se envían el historial ni tus preferencias. '
                'Requiere internet y un backend configurado.',
              ),
              value: widget.database.aiEnabled,
              onChanged: (value) {
                widget.database.setAiEnabled(value);
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Enviar comentarios'),
              subtitle: const Text('Comparte sugerencias o reporta un problema.'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FeedbackScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estilo de conversación',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          RadioListTile<String>(
            title: const Text('Cercano'),
            value: 'cercano',
            groupValue: widget.database.style,
            onChanged: (value) {
              if (value == null) return;
              widget.database.setStyle(value);
              setState(() {});
            },
          ),
          RadioListTile<String>(
            title: const Text('Breve'),
            value: 'breve',
            groupValue: widget.database.style,
            onChanged: (value) {
              if (value == null) return;
              widget.database.setStyle(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tus preferencias',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (enabled)
                IconButton(
                  tooltip: 'Añadir preferencia',
                  onPressed: _addMemory,
                  icon: const Icon(Icons.add),
                ),
              if (memories.isNotEmpty)
                IconButton(
                  tooltip: 'Borrar todas',
                  onPressed: _clearMemories,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (!enabled)
            const Text('Activa la memoria para añadir preferencias.'),
          for (final memory in memories)
            Card(
              child: ListTile(
                title: Text(memory.note),
                trailing: IconButton(
                  tooltip: 'Eliminar preferencia',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.database.deleteMemory(memory.id);
                    setState(() {});
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
