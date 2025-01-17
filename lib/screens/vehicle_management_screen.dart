import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';
import '../services/firebase_service.dart';
import 'profit_loss_screen.dart';

class VehicleManagementScreen extends StatefulWidget {
  @override
  _VehicleManagementScreenState createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _status = '';

  Future<void> _showAddVehicleDialog() async {
    final idController = TextEditingController();
    final costController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration:
                  InputDecoration(labelText: 'Vehicle ID (e.g., plate number)'),
            ),
            TextField(
              controller: costController,
              decoration: InputDecoration(labelText: 'Initial Cost'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (idController.text.isNotEmpty &&
                  costController.text.isNotEmpty) {
                await _firebaseService.addVehicle(
                  idController.text.trim(),
                  {
                    'id': idController.text.trim(),
                    'initial_cost': double.parse(costController.text),
                    'assigned_drivers': [],
                    'maintenance_costs': [],
                    'additional_costs': [],
                  },
                );
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCostDialog(String vehicleId) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String costType = 'maintenance';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Cost'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: costType,
                items: ['maintenance', 'additional']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => costType = value!),
              ),
              TextField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  await _firebaseService.addVehicleCost(
                    vehicleId,
                    costType,
                    {
                      'date': DateTime.now().toIso8601String(),
                      'amount': double.parse(amountController.text),
                      'note': noteController.text.trim(),
                    },
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDriverAssignmentDialog(String vehicleId) async {
    final drivers = await _firebaseService.getDrivers().first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Driver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: drivers.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? 'Unknown Driver'),
                onTap: () {
                  _firebaseService.assignDriverToVehicle(vehicleId, doc.id);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getVehicles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final vehicle = Vehicle.fromJson(data);

            return ExpansionTile(
              title: Text('Vehicle: ${vehicle.id}'),
              subtitle: Text('Initial Cost: \$${vehicle.initialCost}'),
              children: [
                ListTile(
                  title: Text('Assigned Drivers'),
                  trailing: IconButton(
                    icon: Icon(Icons.person_add),
                    onPressed: () => _showDriverAssignmentDialog(vehicle.id),
                  ),
                ),
                ...vehicle.assignedDrivers.map((driverId) => ListTile(
                      title: Text(driverId),
                      trailing: IconButton(
                        icon: Icon(Icons.person_remove),
                        onPressed: () =>
                            _firebaseService.removeDriverFromVehicle(
                          vehicle.id,
                          driverId,
                        ),
                      ),
                    )),
                ListTile(
                  title: Text('Add Cost'),
                  trailing: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () => _showAddCostDialog(vehicle.id),
                  ),
                ),
                _buildCostsList(vehicle.id),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCostsList(String vehicleId) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _firebaseService.getVehicleCosts(vehicleId, 'maintenance'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Container();
            return Column(
              children: [
                Text('Maintenance Costs',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('\$${data['amount']}'),
                    subtitle: Text('${data['date']}\n${data['note']}'),
                  );
                }),
              ],
            );
          },
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _firebaseService.getVehicleCosts(vehicleId, 'additional'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Container();
            return Column(
              children: [
                Text('Additional Costs',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('\$${data['amount']}'),
                    subtitle: Text('${data['date']}\n${data['note']}'),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicle Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.assessment),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfitLossScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildVehicleList()),
          if (_status.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(_status),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVehicleDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
