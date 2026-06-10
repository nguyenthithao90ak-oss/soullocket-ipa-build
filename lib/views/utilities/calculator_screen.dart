import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const List<String> _buttons = [
    'C',
    '( )',
    '⌫',
    '÷',
    '7',
    '8',
    '9',
    '×',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '+',
    '0',
    '.',
    '%',
    '=',
  ];

  String _expression = '';
  String _result = '0';
  final List<String> _history = <String>[];

  bool get _canEvaluate => _expression.trim().isNotEmpty;

  void _onButtonPressed(String value) {
    switch (value) {
      case 'C':
        setState(() {
          _expression = '';
          _result = '0';
        });
        break;
      case '⌫':
        if (_expression.isEmpty) return;
        setState(() {
          _expression = _expression.substring(0, _expression.length - 1);
          if (_expression.isEmpty) _result = '0';
        });
        break;
      case '( )':
        _insertBracket();
        break;
      case '=':
        _evaluateExpression(commitHistory: true);
        break;
      default:
        setState(() {
          _expression += value;
        });
        if (_canEvaluate) {
          _evaluateExpression(commitHistory: false);
        }
    }
  }

  void _insertBracket() {
    final opens = '('.allMatches(_expression).length;
    final closes = ')'.allMatches(_expression).length;
    final trimmed = _expression.trimRight();
    final lastChar =
        trimmed.isEmpty ? '' : trimmed.substring(trimmed.length - 1);
    final shouldOpen =
        trimmed.isEmpty || '+-×÷('.contains(lastChar) || opens == closes;

    setState(() {
      _expression += shouldOpen ? '(' : ')';
    });
  }

  void _evaluateExpression({required bool commitHistory}) {
    try {
      final parser = _SafeExpressionParser(
        _expression.replaceAll('×', '*').replaceAll('÷', '/'),
      );
      final value = parser.parse();
      final formatted = _formatNumber(value);

      setState(() {
        _result = formatted;
        if (commitHistory) {
          final historyItem = '${_expression.trim()} = $formatted';
          if (!_history.contains(historyItem)) {
            _history.insert(0, historyItem);
            if (_history.length > 6) {
              _history.removeLast();
            }
          }
          _expression = formatted;
        }
      });
    } catch (error) {
      if (!commitHistory) return;
      setState(() {
        _result =
            error is FormatException ? error.message : L10nService().translate('util_biuthcchah_e4f8bc');
      });
    }
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) {
      return L10nService().translate('util_khnghpl_a3991c');
    }
    if ((value - value.round()).abs() < 0.0000001) {
      return value.round().toString();
    }
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  bool _isActionButton(String value) {
    return const {'C', '( )', '⌫', '÷', '×', '-', '+', '=', '%'}
        .contains(value);
  }

  bool _isPrimaryButton(String value) {
    return const {'=', '÷', '×', '-', '+'}.contains(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, L10nService().translate('util_mytnh_fcce20')),
      body: SLTheme.background(
        child: SafeArea(
          child: Column(
            children: [
              _buildDisplay(),
              if (_history.isNotEmpty) _buildHistory(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _buttons.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final value = _buttons[index];
                    final isAction = _isActionButton(value);
                    final isPrimary = _isPrimaryButton(value);
                    return _CalculatorButton(
                      label: value,
                      onTap: () => _onButtonPressed(value),
                      background: isPrimary
                          ? const LinearGradient(
                              colors: [Color(0xFFD81B60), Color(0xFFF06292)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      fillColor: isAction
                          ? const Color(0xFFFFF0F6)
                          : Colors.white.withValues(alpha: 0.94),
                      textColor: isPrimary
                          ? Colors.white
                          : isAction
                              ? const Color(0xFFD81B60)
                              : const Color(0xFF24344A),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            L10nService().translate('util_biuthc_e6993f'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8894A8),
            ),
          ),
          SLSpacing.h6,
          Text(
            _expression.isEmpty ? '0' : _expression,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2A3D),
            ),
          ),
          SLSpacing.h12,
          Text(
            L10nService().translate('util_ktqu_80d598'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8A7AA1),
            ),
          ),
          SLSpacing.h6,
          Text(
            _result,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD81B60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: const Color(0xFFFFE0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                L10nService().translate('util_tnhgny_8a207f'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD81B60),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(_history.clear),
                child: Text(
                  L10nService().translate(L10nService().translate('util_xa_4ed187')),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7A8AA0),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h8,
          ..._history.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  color: const Color(0xFF324055),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final LinearGradient? background;
  final Color fillColor;
  final Color textColor;

  const _CalculatorButton({
    required this.label,
    required this.onTap,
    required this.fillColor,
    required this.textColor,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.xlAll,
        child: Ink(
          decoration: BoxDecoration(
            gradient: background,
            color: background == null ? fillColor : null,
            borderRadius: SLRadius.xlAll,
            border: Border.all(
              color: background == null
                  ? const Color(0xFFFFDFEB)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeExpressionParser {
  final String _input;
  int _index = 0;

  _SafeExpressionParser(this._input);

  double parse() {
    final value = _parseExpression();
    _skipSpaces();
    if (_index != _input.length) {
      throw FormatException(L10nService().translate('util_biuthcchah_e4f8bc'));
    }
    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipSpaces();
      if (_match('*')) {
        value *= _parseFactor();
      } else if (_match('/')) {
        final divisor = _parseFactor();
        if (divisor == 0) {
          throw FormatException(L10nService().translate('util_khngthchia_9602c6'));
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parseFactor() {
    _skipSpaces();

    if (_match('+')) return _parseFactor();
    if (_match('-')) return -_parseFactor();

    if (_match('(')) {
      final value = _parseExpression();
      _skipSpaces();
      if (!_match(')')) {
        throw FormatException(L10nService().translate('util_thiudungng_ff9ccf'));
      }
      return _applyPercentIfNeeded(value);
    }

    final number = _parseNumber();
    return _applyPercentIfNeeded(number);
  }

  double _applyPercentIfNeeded(double value) {
    _skipSpaces();
    if (_match('%')) {
      return value / 100;
    }
    return value;
  }

  double _parseNumber() {
    _skipSpaces();
    final start = _index;
    var hasDot = false;

    while (_index < _input.length) {
      final char = _input[_index];
      if (char == '.') {
        if (hasDot) break;
        hasDot = true;
        _index++;
        continue;
      }
      if (_isDigit(char)) {
        _index++;
        continue;
      }
      break;
    }

    if (start == _index) {
      throw FormatException(L10nService().translate('util_biuthcchah_e4f8bc'));
    }

    return double.parse(_input.substring(start, _index));
  }

  void _skipSpaces() {
    while (_index < _input.length && _input[_index].trim().isEmpty) {
      _index++;
    }
  }

  bool _match(String value) {
    if (_index >= _input.length || _input[_index] != value) return false;
    _index++;
    return true;
  }

  bool _isDigit(String value) =>
      value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;
}
