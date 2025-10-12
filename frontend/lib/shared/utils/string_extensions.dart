extension StringCasingExtension on String {
  String capitalizeAll() => split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
}
