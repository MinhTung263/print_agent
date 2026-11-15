/// Kết quả "In thử" một máy in.
enum AgentTestPrintResult {
  /// Máy in đã in phiếu thử.
  done,

  /// Máy in hết giấy / mở nắp: Agent giữ phiếu và tự in khi sẵn sàng lại.
  held,

  /// In lỗi (máy in tắt, mất kết nối...).
  failed,

  /// Trạm in quản lý máy in (máy khác) đang tắt / mất kết nối.
  offline,
}
