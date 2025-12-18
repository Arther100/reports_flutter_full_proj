import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/powerbi_models.dart';

class DynamicDateRangeSelector extends StatefulWidget {
  final DynamicDateRange initialRange;
  final Function(DynamicDateRange) onRangeChanged;
  final Color? accentColor;

  const DynamicDateRangeSelector({
    super.key,
    required this.initialRange,
    required this.onRangeChanged,
    this.accentColor,
  });

  @override
  State<DynamicDateRangeSelector> createState() =>
      _DynamicDateRangeSelectorState();
}

class _DynamicDateRangeSelectorState extends State<DynamicDateRangeSelector> {
  late String _selectedType;
  late int _value;
  late String _unit;
  late DateTime _startDate;
  late DateTime _endDate;

  final List<Map<String, dynamic>> _presets = [
    {'label': 'Last 1 Month', 'value': 1, 'unit': 'months'},
    {'label': 'Last 3 Months', 'value': 3, 'unit': 'months'},
    {'label': 'Last 6 Months', 'value': 6, 'unit': 'months'},
    {'label': 'Last 30 Days', 'value': 30, 'unit': 'days'},
    {'label': 'Last 90 Days', 'value': 90, 'unit': 'days'},
    {'label': 'This Month', 'type': 'this', 'unit': 'month'},
    {'label': 'This Quarter', 'type': 'this', 'unit': 'quarter'},
    {'label': 'This Year', 'type': 'this', 'unit': 'year'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialRange.type;
    _value = widget.initialRange.value ?? 1;
    _unit = widget.initialRange.unit ?? 'months';
    final dates = widget.initialRange.getDateRange();
    _startDate = dates['start']!;
    _endDate = dates['end']!;
  }

  Color get _accentColor => widget.accentColor ?? Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withOpacity(0.1),
            _accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(),
                const SizedBox(height: 16),
                if (_selectedType == 'last') _buildLastNSelector(),
                if (_selectedType == 'this') _buildThisSelector(),
                if (_selectedType == 'custom') _buildCustomSelector(),
                const SizedBox(height: 16),
                _buildPresets(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: _accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dynamic Date Range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
                Text(
                  _buildRangeText(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _buildTypeChip('last', 'Last N', Icons.history),
        const SizedBox(width: 8),
        _buildTypeChip('this', 'Current', Icons.today),
        const SizedBox(width: 8),
        _buildTypeChip('custom', 'Custom', Icons.edit_calendar),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type == 'last') {
              _value = 1;
              _unit = 'months';
            } else if (type == 'this') {
              _unit = 'month';
            }
            _updateRange();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _accentColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastNSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Last',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildValueSlider()),
            const SizedBox(width: 12),
            _buildUnitDropdown(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Calculating: ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildValueSlider() {
    final maxValue = _unit == 'months' ? 12 : (_unit == 'weeks' ? 52 : 365);
    return Column(
      children: [
        Text(
          '$_value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        Slider(
          value: _value.toDouble(),
          min: 1,
          max: maxValue.toDouble(),
          divisions: maxValue - 1,
          activeColor: _accentColor,
          onChanged: (value) {
            setState(() {
              _value = value.toInt();
              _updateRange();
            });
          },
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: _unit,
        underline: const SizedBox(),
        items: [
          DropdownMenuItem(
            value: 'days',
            child: Text('Days', style: _dropdownTextStyle()),
          ),
          DropdownMenuItem(
            value: 'weeks',
            child: Text('Weeks', style: _dropdownTextStyle()),
          ),
          DropdownMenuItem(
            value: 'months',
            child: Text('Months', style: _dropdownTextStyle()),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _unit = value;
              // Reset value to reasonable default for new unit
              if (value == 'months' && _value > 12) _value = 12;
              if (value == 'weeks' && _value > 52) _value = 52;
              if (value == 'days' && _value > 365) _value = 365;
              _updateRange();
            });
          }
        },
      ),
    );
  }

  Widget _buildThisSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildThisChip('week', 'This Week'),
            _buildThisChip('month', 'This Month'),
            _buildThisChip('quarter', 'This Quarter'),
            _buildThisChip('year', 'This Year'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Range: ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildThisChip(String unit, String label) {
    final isSelected = _unit == unit;
    return InkWell(
      onTap: () {
        setState(() {
          _unit = unit;
          _updateRange();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateButton('From', _startDate, (date) {
                setState(() {
                  _startDate = date;
                  _updateRange();
                });
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateButton('To', _endDate, (date) {
                setState(() {
                  _endDate = date;
                  _updateRange();
                });
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Duration: ${_endDate.difference(_startDate).inDays} days',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDateButton(
    String label,
    DateTime date,
    Function(DateTime) onDateSelected,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: _accentColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Presets',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((preset) {
            return InkWell(
              onTap: () {
                setState(() {
                  if (preset.containsKey('type')) {
                    _selectedType = preset['type'];
                    _unit = preset['unit'];
                  } else {
                    _selectedType = 'last';
                    _value = preset['value'];
                    _unit = preset['unit'];
                  }
                  _updateRange();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  preset['label'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _updateRange() {
    DynamicDateRange range;
    if (_selectedType == 'last') {
      range = DynamicDateRange.last(_value, _unit);
    } else if (_selectedType == 'this') {
      range = DynamicDateRange.current(_unit);
    } else {
      range = DynamicDateRange.custom(_startDate, _endDate);
    }

    final dates = range.getDateRange();
    _startDate = dates['start']!;
    _endDate = dates['end']!;

    widget.onRangeChanged(range);
  }

  String _buildRangeText() {
    if (_selectedType == 'last') {
      return 'Last $_value ${_unit[0].toUpperCase()}${_unit.substring(1)}';
    } else if (_selectedType == 'this') {
      return 'This ${_unit[0].toUpperCase()}${_unit.substring(1)}';
    } else {
      return '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  TextStyle _dropdownTextStyle() {
    return TextStyle(fontSize: 13, color: Colors.grey[700]);
  }
}
