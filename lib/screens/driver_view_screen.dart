import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class DriverViewScreen extends StatefulWidget {
  final String driverId;
  final String driverName;

  DriverViewScreen({required this.driverId, required this.driverName});

  @override
  _DriverViewScreenState createState() => _DriverViewScreenState();
}

class _DriverViewScreenState extends State<DriverViewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _sortField = 'date';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Details: ${widget.driverName}',
            style: TextStyle(
                color: Theme.of(context).appBarTheme.titleTextStyle?.color)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort,
                color: Theme.of(context).appBarTheme.titleTextStyle?.color),
            onSelected: (String field) {
              setState(() {
                if (_sortField == field) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortField = field;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                        _sortField == 'date'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : null,
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    SizedBox(width: 8),
                    Text('Sort by Date',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(
                        _sortField == 'amount'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : null,
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    SizedBox(width: 8),
                    Text('Sort by Amount',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'order_number',
                child: Row(
                  children: [
                    Icon(
                        _sortField == 'order_number'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : null,
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    SizedBox(width: 8),
                    Text('Sort by Order Number',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildDriverDetails(),
    );
  }

  Widget _buildDriverDetails() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getDriverPayments(
        widget.driverId,
        sortField: _sortField,
        ascending: _sortAscending,
      ),
      builder: (context, paymentSnapshot) {
        if (!paymentSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final payments = paymentSnapshot.data!.docs;
        if (payments.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No payments found',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
          );
        }

        // Group payments by week
        Map<int, List<QueryDocumentSnapshot>> paymentsByWeek = {};
        for (var payment in payments) {
          final data = payment.data() as Map<String, dynamic>;
          final date = DateTime.parse(data['date'] as String);
          final weekNumber =
              (date.difference(DateTime(date.year, 1, 1)).inDays / 7).ceil();
          paymentsByWeek.putIfAbsent(weekNumber, () => []).add(payment);
        }

        double totalGross = 0;
        double totalCommission = 0;
        double totalMaintenance = 0;
        double totalInsurance = 0;
        double totalNet = 0;

        // Process payments by week
        paymentsByWeek.forEach((weekNumber, weekPayments) {
          bool insuranceDeducted = false;

          for (var payment in weekPayments) {
            final data = payment.data() as Map<String, dynamic>;
            final amount = data['amount'] as double? ?? 0.0;
            final isZellePayment = data['type'] == 'zelle_payment';
            final isMaintenanceFee = data['maintenance_fee'] != null;
            final insuranceFee = data['insurance_fee'] as double? ?? 0.0;

            if (isZellePayment || isMaintenanceFee) {
              // For Zelle and maintenance payments, add to totals without deductions
              totalGross += amount;
              totalNet += amount;
              if (isMaintenanceFee) {
                totalMaintenance += amount;
              }
            } else {
              // Regular payment calculations
              final commission = amount * 0.30;
              final netAmount = amount -
                  commission -
                  (insuranceDeducted ? 0.0 : insuranceFee);

              totalGross += amount;
              totalCommission += commission;
              totalInsurance += insuranceDeducted ? 0.0 : insuranceFee;
              totalNet += netAmount;
              insuranceDeducted = true;
            }
          }
        });

        return SingleChildScrollView(
          child: Column(
            children: [
              // Summary Card
              Card(
                margin: EdgeInsets.all(8.0),
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Summary:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Text('Gross Total: \$${totalGross.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Text(
                          'Commission (30%): -\$${totalCommission.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Text(
                          'Maintenance (10%): -\$${totalMaintenance.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Text('Insurance: -\$${totalInsurance.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Divider(
                        color: Theme.of(context).dividerColor,
                      ),
                      Text('Net Total: \$${totalNet.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                    ],
                  ),
                ),
              ),
              // Payment List
              ...payments.map((payment) {
                final data = payment.data() as Map<String, dynamic>;
                final amount = data['amount'] as double? ?? 0.0;
                final isZellePayment = data['type'] == 'zelle_payment';
                final isMaintenanceFee = data['maintenance_fee'] != null;
                final insuranceFee = data['insurance_fee'] as double? ?? 0.0;
                final date = DateTime.parse(data['date'] as String);
                final weekNumber =
                    (date.difference(DateTime(date.year, 1, 1)).inDays / 7)
                        .ceil();

                bool isFirstPaymentOfWeek =
                    paymentsByWeek[weekNumber]?.first.id == payment.id;

                // Calculate net amount based on payment type
                final netAmount = isZellePayment || isMaintenanceFee
                    ? amount // No deductions for Zelle or maintenance
                    : amount -
                        (amount * 0.30) -
                        (isFirstPaymentOfWeek ? insuranceFee : 0.0);

                return ListTile(
                  title: Text('Order: ${data['order_number'] ?? 'N/A'}',
                      style: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: ${data['date'] ?? 'N/A'}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Text('Amount: \$${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      if (isZellePayment)
                        Text('Zelle Payment',
                            style: TextStyle(color: Colors.blue)),
                      if (isMaintenanceFee)
                        Text('Maintenance Fee',
                            style: TextStyle(color: Colors.orange)),
                      if (!isZellePayment && !isMaintenanceFee) ...[
                        Text(
                            'Net after deductions: \$${netAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.green)),
                        if (isFirstPaymentOfWeek && insuranceFee > 0)
                          Text(
                              'Insurance Deducted: -\$${insuranceFee.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.red)),
                      ],
                      if (isMaintenanceFee)
                        Text(
                            'Maintenance Comment: ${data['comment'] ?? 'No comment'}',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
