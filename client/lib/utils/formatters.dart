class Formatters {
  static String formatCents(int cents) {
    final dollars = cents / 100;
    final parts = dollars.toStringAsFixed(2).split('.');
    final buf = StringBuffer();
    int c = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
      c++;
    }
    return '\$${buf.toString().split('').reversed.join()}.${parts[1]}';
  }

  static String formatAbn(String abn) {
    final d = abn.replaceAll(' ', '');
    if (d.length != 11) return abn;
    return '${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 8)} ${d.substring(8)}';
  }

  static String formatDateShort(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
