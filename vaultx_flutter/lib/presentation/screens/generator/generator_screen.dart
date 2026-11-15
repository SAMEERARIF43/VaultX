import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../domain/models/security_audit_models.dart';
import '../../../domain/models/vault_record_type.dart';
import '../../widgets/vaultx_widgets.dart';
import '../vault/record_editor_sheet.dart';

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  PasswordGeneratorOptions _options = const PasswordGeneratorOptions();
  late String _generated;

  @override
  void initState() {
    super.initState();
    _generated = ref.read(passwordGeneratorServiceProvider).generate(_options);
  }

  void _regenerate([PasswordGeneratorOptions? next]) {
    final target = next ?? _options;
    try {
      final pw = ref.read(passwordGeneratorServiceProvider).generate(target);
      setState(() {
        _options = target;
        _generated = pw;
      });
    } catch (e) {
      showVaultSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pwService = ref.read(passwordGeneratorServiceProvider);
    final strength = pwService.evaluateStrength(_generated);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.password_rounded),
              label: Text('Random Password'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.notes_rounded),
              label: Text('Passphrase'),
            ),
          ],
          selected: {_options.passphraseMode},
          onSelectionChanged: (set) {
            _regenerate(_options.copyWith(passphraseMode: set.first));
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  _generated,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                PasswordStrengthMeter(result: strength),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _regenerate(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Regenerate'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await ref
                              .read(vaultSessionProvider.notifier)
                              .copySensitiveValue(
                                _generated,
                                label: 'Generated password',
                                isSensitive: true,
                              );
                          if (context.mounted) {
                            showVaultSnackBar(
                              context,
                              'Copied with automatic clipboard wipe.',
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_options.passphraseMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Length',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_options.length} chars',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _options.length.toDouble(),
                    min: 8,
                    max: 64,
                    divisions: 56,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(length: v.round())),
                  ),
                  SwitchListTile(
                    title: const Text('Uppercase Letters (A–Z)'),
                    value: _options.uppercase,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(uppercase: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Lowercase Letters (a–z)'),
                    value: _options.lowercase,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(lowercase: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Numbers (0–9)'),
                    value: _options.numbers,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(numbers: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Special Symbols (!@#...)'),
                    value: _options.symbols,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(symbols: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Exclude Ambiguous (0, O, l, 1)'),
                    value: _options.excludeAmbiguous,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(excludeAmbiguous: v)),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Word Count',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_options.wordCount} words',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _options.wordCount.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(wordCount: v.round())),
                  ),
                  SwitchListTile(
                    title: const Text('Capitalize Words'),
                    value: _options.capitalizeWords,
                    onChanged: (v) =>
                        _regenerate(_options.copyWith(capitalizeWords: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Include Random 2-Digit Number'),
                    value: _options.includeNumberInPassphrase,
                    onChanged: (v) => _regenerate(
                      _options.copyWith(includeNumberInPassphrase: v),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showRecordEditorSheet(
              context,
              initialType: VaultRecordType.login,
              prefilledPassword: _generated,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Save to New Login Credential'),
          ),
        ),
      ],
    );
  }
}
