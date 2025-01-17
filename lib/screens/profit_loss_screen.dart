import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';
import '../services/firebase_service.dart';

class ProfitLossScreen extends StatefulWidget {
  @override
  _ProfitLossScreenState createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<Map<String, dynamic>> _generateReport() async {
    try {
      final vehicles = await _firebaseService.getVehicles().first;
      final report = {
        'overall': {
          'total_revenue': 0.0,
          'total_commission': 0.0,
          'total_insurance': 0.0,
          'total_vehicle_costs': 0.0,
          'net_profit': 0.0,
        },
        'vehicles': <String, dynamic>{},
      };

      for (final vehicleDoc in vehicles.docs) {
        final vehicleData = vehicleDoc.data() as Map<String, dynamic>?;
        if (vehicleData == null) continue;
        final vehicle = Vehicle.fromJson(vehicleData);
        final vehicleReport = _createVehicleReport(vehicle);

        // Calculate maintenance costs within date range
        final maintenanceCosts = await _firebaseService
            .getVehicleCosts(vehicle.id, 'maintenance')
            .first;
        _processCosts(maintenanceCosts, vehicleReport, 'maintenance_costs');

        // Calculate additional costs within date range
        final additionalCosts = await _firebaseService
            .getVehicleCosts(vehicle.id, 'additional')
            .first;
        _processCosts(additionalCosts, vehicleReport, 'additional_costs');

        // Calculate driver-specific revenue and costs
        for (final driverId in vehicle.assignedDrivers) {
          await _processDriverPayments(driverId, vehicleReport);
        }

        _calculateVehicleNetProfit(vehicleReport);
        report['vehicles'] ??= {};
        report['vehicles']![vehicle.id] = vehicleReport;
        _updateOverallTotals(report, vehicleReport);
      }

      _calculateOverallNetProfit(report);
      return report;
    } catch (e) {
      print("Error generating report: $e");
      return {};
    }
  }

  Map<String, dynamic> _createVehicleReport(Vehicle vehicle) {
    return {
      'revenue': 0.0,
      'commission': 0.0,
      'insurance_collected': 0.0,
      'initial_cost': vehicle.initialCost,
      'maintenance_costs': 0.0,
      'additional_costs': 0.0,
      'net_profit': 0.0,
      'drivers': <String, dynamic>{},
    };
  }

  void _processCosts(
      QuerySnapshot costs, Map<String, dynamic> report, String costType) {
    for (final costDoc in costs.docs) {
      final costData = costDoc.data() as Map<String, dynamic>?;
      if (costData == null) continue;
      final date = DateTime.tryParse(costData['date']?.toString() ?? '');
      if (date != null && date.isAfter(_startDate) && date.isBefore(_endDate)) {
        report[costType] = (report[costType] as num? ?? 0.0) +
            (costData['amount'] as num? ?? 0.0);
      }
    }
  }

  Future<void> _processDriverPayments(
      String driverId, Map<String, dynamic> vehicleReport) async {
    final driverPayments =
        await _firebaseService.getDriverPayments(driverId).first;
    final filteredPayments = driverPayments.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final date = DateTime.tryParse(data['date']?.toString() ?? '');
      return date != null &&
          date.isAfter(_startDate) &&
          date.isBefore(_endDate);
    }).toList();

    final driverReport = {
      'revenue': 0.0,
      'commission': 0.0,
      'insurance_collected': 0.0,
    };

    for (final paymentDoc in filteredPayments) {
      final payment = paymentDoc.data() as Map<String, dynamic>?;
      if (payment == null) continue;
      if (payment['type'] != 'zelle_payment') {
        final amount = payment['amount'] as double? ?? 0.0;
        driverReport['revenue'] = (driverReport['revenue'] ?? 0.0) + amount;
        driverReport['commission'] =
            (driverReport['commission'] ?? 0.0) + amount * 0.30;
        if (payment['insurance_fee'] != null) {
          driverReport['insurance_collected'] =
              (driverReport['insurance_collected'] ?? 0.0) +
                  (payment['insurance_fee'] as double? ?? 0.0);
        }
      }
    }

    vehicleReport['drivers'][driverId] = driverReport;
    vehicleReport['revenue'] =
        (vehicleReport['revenue'] ?? 0.0) + driverReport['revenue'];
    vehicleReport['commission'] = (vehicleReport['commission'] as num? ?? 0.0) +
        (driverReport['commission'] as num? ?? 0.0);
    vehicleReport['insurance_collected'] =
        (vehicleReport['insurance_collected'] as num? ?? 0.0) +
            (driverReport['insurance_collected'] as num? ?? 0.0);
  }

  void _calculateVehicleNetProfit(Map<String, dynamic> vehicleReport) {
    final totalCosts = (vehicleReport['maintenance_costs'] as num? ?? 0.0) +
        (vehicleReport['additional_costs'] as num? ?? 0.0);
    vehicleReport['net_profit'] = (vehicleReport['commission'] as num? ?? 0.0) +
        (vehicleReport['insurance_collected'] as num? ?? 0.0) -
        totalCosts;
  }

  void _updateOverallTotals(
      Map<String, dynamic> report, Map<String, dynamic> vehicleReport) {
    report['overall']['total_revenue'] =
        (report['overall']?['total_revenue'] as num? ?? 0.0) +
            (vehicleReport['revenue'] as num? ?? 0.0);
    report['overall']['total_commission'] =
        (report['overall']?['total_commission'] as num? ?? 0.0) +
            (vehicleReport['commission'] as num? ?? 0.0);
    report['overall']['total_insurance'] =
        (report['overall']?['total_insurance'] as num? ?? 0.0) +
            (vehicleReport['insurance_collected'] as num? ?? 0.0);
    report['overall']['total_vehicle_costs'] =
        (report['overall']?['total_vehicle_costs'] as num? ?? 0.0) +
            (vehicleReport['maintenance_costs'] as num? ?? 0.0) +
            (vehicleReport['additional_costs'] as num? ?? 0.0);
  }

  void _calculateOverallNetProfit(Map<String, dynamic> report) {
    report['overall']['net_profit'] =
        (report['overall']?['total_commission'] as num? ?? 0.0) +
            (report['overall']?['total_insurance'] as num? ?? 0.0) -
            (report['overall']?['total_vehicle_costs'] as num? ?? 0.0);
  }

  Widget _buildReportView(Map<String, dynamic> report) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Summary',
                        style: Theme.of(context).textTheme.titleLarge),
                    Divider(
                      color: Theme.of(context).dividerColor,
                    ),
                    _buildSummaryRow('Total Revenue',
                        '\$${report['overall']?['total_revenue']?.toStringAsFixed(2) ?? '0.00'}'),
                    _buildSummaryRow('Total Commission',
                        '\$${report['overall']?['total_commission']?.toStringAsFixed(2) ?? '0.00'}'),
                    _buildSummaryRow('Total Insurance',
                        '\$${report['overall']?['total_insurance']?.toStringAsFixed(2) ?? '0.00'}'),
                    _buildSummaryRow('Total Vehicle Costs',
                        '\$${report['overall']?['total_vehicle_costs']?.toStringAsFixed(2) ?? '0.00'}'),
                    Divider(
                      color: Theme.of(context).dividerColor,
                    ),
                    _buildSummaryRow('Net Profit',
                        '\$${report['overall']?['net_profit']?.toStringAsFixed(2) ?? '0.00'}',
                        isTotal: true),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text('Vehicle Details',
                style: Theme.of(context).textTheme.titleLarge),
            ...(report['vehicles'] as Map<String, dynamic>?)
                    ?.entries
                    .map(
                      (entry) => _buildVehicleCard(entry.key, entry.value),
                    )
                    .toList() ??
                [],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isTotal
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color)
                  : TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color)),
          Text(value,
              style: isTotal
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color)
                  : TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(String vehicleId, Map<String, dynamic> vehicleData) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Text('Vehicle: $vehicleId',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color)),
        subtitle: Text(
            'Net Profit: \$${vehicleData['net_profit']?.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color)),
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Revenue',
                    '\$${vehicleData['revenue']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildSummaryRow('Commission',
                    '\$${vehicleData['commission']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildSummaryRow('Insurance',
                    '\$${vehicleData['insurance_collected']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildSummaryRow('Maintenance',
                    '\$${vehicleData['maintenance_costs']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildSummaryRow('Additional Costs',
                    '\$${vehicleData['additional_costs']?.toStringAsFixed(2) ?? '0.00'}'),
                if ((vehicleData['drivers'] as Map?)?.isNotEmpty ?? false) ...[
                  Divider(
                    color: Theme.of(context).dividerColor,
                  ),
                  Text('Driver Breakdown',
                      style: Theme.of(context).textTheme.titleMedium),
                  ...(vehicleData['drivers'] as Map<String, dynamic>?)
                          ?.entries
                          .map((driver) =>
                              _buildDriverSummary(driver.key, driver.value))
                          .toList() ??
                      [],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSummary(String driverId, Map<String, dynamic> driverData) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Driver: $driverId',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
            _buildSummaryRow('Revenue',
                '\$${driverData['revenue']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildSummaryRow('Commission',
                '\$${driverData['commission']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildSummaryRow('Insurance',
                '\$${driverData['insurance_collected']?.toStringAsFixed(2) ?? '0.00'}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profit & Loss Report',
            style: TextStyle(
                color: Theme.of(context).appBarTheme.titleTextStyle?.color)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(
                  start: _startDate,
                  end: _endDate,
                ),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _generateReport(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No data available'));
          }
          return _buildReportView(snapshot.data!);
        },
      ),
    );
  }
}
