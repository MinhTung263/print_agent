import '../agent/printer_type.dart';
import 'printer_option.dart';

/// Logic danh sách hộp chọn máy in (thuần — test được): gộp máy dò thấy với máy
/// nhập tay và máy đang dùng, sắp máy đang dùng lên đầu, chọn sẵn khi chỉ có
/// một máy, cập nhật tên model.
abstract final class PrinterPickerList {
  /// [found]: lượt dò; [manual]: máy nhập tay đã kiểm tra; [current]: địa chỉ
  /// máy in đang dùng ([missing] dựng thẻ khi lượt dò không thấy).
  static List<PrinterOption> merge({
    required List<PrinterOption> found,
    List<PrinterOption> manual = const [],
    String current = '',
    PrinterOption Function(String address)? missing,
  }) {
    final all = <PrinterOption>[
      for (final m in manual)
        if (!found.any((o) => o.key == m.key)) m,
      ...found,
    ];
    if (current.isNotEmpty &&
        missing != null &&
        !all.any((o) => o.address == current)) {
      all.insert(0, missing(current));
    }
    // Sắp ổn định: máy đang dùng lên đầu, còn lại giữ thứ tự.
    final cur = [
      for (final o in all)
        if (o.address == current) o,
    ];
    return [
      ...cur,
      for (final o in all)
        if (o.address != current) o,
    ];
  }

  /// Khoá chọn sẵn: giữ [selected]; chưa chọn mà chỉ có một máy → máy đó.
  static String? preselect(List<PrinterOption> all, String? selected) =>
      selected ??
      (all.length == 1 && !all.first.blocked ? all.first.key : null);

  /// Đổi tiêu đề máy in mạng [address] thành tên model [model].
  static List<PrinterOption> withModel(
    List<PrinterOption> all,
    String address,
    String model,
  ) => [
    for (final o in all)
      o.kind == PrinterOptionKind.lan && o.address == address
          ? PrinterOption.lan(
              address,
              model: model,
              type: o.type,
              warning: o.warning,
              hardBlock: o.hardBlock,
            )
          : o,
  ];

  /// Gắn loại máy in (tem / hoá đơn) đã nhận ra cho máy ở [address].
  static List<PrinterOption> withType(
    List<PrinterOption> all,
    String address,
    PrinterType? type,
  ) => [
    for (final o in all)
      o.address.isNotEmpty && o.address == address ? o.withType(type) : o,
  ];
}
