part of raven_app;

enum VaultMode { real, decoy }

enum MessageDeliveryStatus { local, pending, sent, delivered }

extension MessageDeliveryStatusView on MessageDeliveryStatus {
  String get storageValue {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return 'pending';
      case MessageDeliveryStatus.sent:
        return 'sent';
      case MessageDeliveryStatus.delivered:
        return 'delivered';
      case MessageDeliveryStatus.local:
        return 'local';
    }
  }

  String get label {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return 'pending';
      case MessageDeliveryStatus.sent:
        return 'sent';
      case MessageDeliveryStatus.delivered:
        return 'delivered';
      case MessageDeliveryStatus.local:
        return 'local';
    }
  }

  IconData get icon {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return Icons.schedule_rounded;
      case MessageDeliveryStatus.sent:
        return Icons.done_rounded;
      case MessageDeliveryStatus.delivered:
        return Icons.done_all_rounded;
      case MessageDeliveryStatus.local:
        return Icons.save_rounded;
    }
  }

}

MessageDeliveryStatus messageDeliveryStatusFromStorage(String? value) {
  switch (value) {
    case 'pending':
      return MessageDeliveryStatus.pending;
    case 'sent':
      return MessageDeliveryStatus.sent;
    case 'delivered':
      return MessageDeliveryStatus.delivered;
    case 'local':
    default:
      return MessageDeliveryStatus.local;
  }
}

