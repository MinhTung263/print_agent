import 'package:flutter/material.dart';

import '../../../auth/auth_service.dart';
import '../../agent_theme.dart';

/// Chọn công ty sau đăng nhập — có tìm kiếm (tài khoản có thể thuộc hàng trăm
/// công ty), hiện tối đa [_maxShown] kết quả.
class CompanyPicker extends StatefulWidget {
  const CompanyPicker({
    super.key,
    required this.result,
    required this.onBack,
    required this.onChoose,
  });

  final LoginResult result;
  final VoidCallback onBack;
  final ValueChanged<CompanyChoice> onChoose;

  @override
  State<CompanyPicker> createState() => _CompanyPickerState();
}

class _CompanyPickerState extends State<CompanyPicker> {
  static const int _maxShown = 50;
  String _query = '';

  List<CompanyChoice> get _filtered => _query.isEmpty
      ? widget.result.companies
      : [
          for (final c in widget.result.companies)
            if (c.name.toLowerCase().contains(_query) ||
                '${c.id}'.contains(_query) ||
                c.address.toLowerCase().contains(_query))
              c,
        ];

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Quay lại',
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Chọn cửa hàng',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Text(
            'Xin chào ${widget.result.fullName}. Máy Agent sẽ in hộ cho cửa '
            'hàng bạn chọn.',
            style: const TextStyle(
              fontSize: 13,
              color: AgentColors.textSecondary,
            ),
          ),
        ),
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText:
                'Tìm theo tên hoặc mã · ${widget.result.companies.length} cửa hàng',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AgentColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AgentColors.primary,
                width: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Không thấy cửa hàng phù hợp',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AgentColors.muted),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length > _maxShown ? _maxShown : list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CompanyTile(
                    company: list[i],
                    onTap: () => widget.onChoose(list[i]),
                  ),
                ),
        ),
        if (list.length > _maxShown)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Gõ thêm để thu hẹp danh sách…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AgentColors.muted),
            ),
          ),
      ],
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({required this.company, required this.onTap});

  final CompanyChoice company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = company;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AgentColors.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AgentColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AgentColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AgentColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        '#${c.id}',
                        if (c.address.isNotEmpty) c.address,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AgentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AgentColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
