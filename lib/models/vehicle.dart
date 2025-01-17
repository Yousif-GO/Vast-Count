class Vehicle {
  final String id;
  final double initialCost;
  final List<String> assignedDrivers;
  final List<VehicleCost> maintenanceCosts;
  final List<VehicleCost> additionalCosts;

  Vehicle({
    required this.id,
    required this.initialCost,
    required this.assignedDrivers,
    required this.maintenanceCosts,
    required this.additionalCosts,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'initial_cost': initialCost,
        'assigned_drivers': assignedDrivers,
        'maintenance_costs': maintenanceCosts.map((c) => c.toJson()).toList(),
        'additional_costs': additionalCosts.map((c) => c.toJson()).toList(),
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'],
        initialCost: json['initial_cost']?.toDouble() ?? 0.0,
        assignedDrivers: List<String>.from(json['assigned_drivers'] ?? []),
        maintenanceCosts: (json['maintenance_costs'] as List?)
                ?.map((c) => VehicleCost.fromJson(c))
                .toList() ??
            [],
        additionalCosts: (json['additional_costs'] as List?)
                ?.map((c) => VehicleCost.fromJson(c))
                .toList() ??
            [],
      );
}

class VehicleCost {
  final DateTime date;
  final double amount;
  final String note;

  VehicleCost({
    required this.date,
    required this.amount,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'note': note,
      };

  factory VehicleCost.fromJson(Map<String, dynamic> json) => VehicleCost(
        date: DateTime.parse(json['date']),
        amount: json['amount']?.toDouble() ?? 0.0,
        note: json['note'] ?? '',
      );
}
