import 'package:flutter/material.dart';
import '../../services/pickup_service.dart';

class PickupRequestStatus extends StatelessWidget {
  final String requestId;
  final PickupService _pickupService = PickupService();

  PickupRequestStatus({Key? key, required this.requestId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _pickupService.getPickupRequestStatus(requestId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          String status = snapshot.data!;
          Color statusColor;
          switch (status) {
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'approved':
              statusColor = Colors.green;
              break;
            case 'declined':
              statusColor = Colors.red;
              break;
            case 'completed':
              statusColor = Colors.blue;
              break;
            default:
              statusColor = Colors.grey;
          }
          return Container(
            padding: EdgeInsets.all(16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: statusColor),
                SizedBox(width: 8),
                Text(
                  'Pickup Request: ${status.toUpperCase()}',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }
}

