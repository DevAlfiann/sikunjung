import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/map_screen.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

Future<void> showVisitDetailSheet(BuildContext context, VisitItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _VisitDetailSheet(item: item),
  );
}

class _VisitDetailSheet extends StatefulWidget {
  final VisitItem item;
  const _VisitDetailSheet({required this.item});

  @override
  State<_VisitDetailSheet> createState() => _VisitDetailSheetState();
}

class _VisitDetailSheetState extends State<_VisitDetailSheet> {
  late String _currentStatus;
  bool _taskChecked1 = true;
  bool _taskChecked2 = false;
  bool _taskChecked3 = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status;
  }

  void _updateStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
      widget.item.status = newStatus;
    });
    AppState.instance.updateVisitStatus(widget.item.id, newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status kunjungan diperbarui: "$newStatus"'),
        backgroundColor: newStatus == 'Selesai'
            ? AppColors.tertiary
            : (newStatus == 'Batal' ? AppColors.error : AppColors.secondary),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _editTaskAndNotes() {
    final taskCtrl = TextEditingController(text: widget.item.task);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Ubah Instruksi Tugas',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: taskCtrl,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tuliskan instruksi tugas kunjungan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = taskCtrl.text.trim();
              if (newText.isNotEmpty) {
                setState(() {
                  widget.item.task = newText;
                });
                AppState.instance.updateVisitDetails(widget.item.id, task: newText);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Instruksi tugas berhasil disimpan ke database.'),
                  backgroundColor: AppColors.tertiary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Hapus Kunjungan?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data kunjungan ke "${widget.item.outletName}" dari database MySQL?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              AppState.instance.deleteVisit(widget.item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kunjungan "${widget.item.outletName}" berhasil dihapus dari database.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Data'),
          ),
        ],
      ),
    );
  }

  void _markComplete() async {
    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final isOffline = AppState.instance.isOfflineMode;
    final newStatus = isOffline ? 'Pending Sync' : 'Selesai';
    AppState.instance.updateVisitStatus(widget.item.id, newStatus);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOffline
                    ? 'Kunjungan disimpan lokal (Mode Offline). Menunggu sinkronisasi.'
                    : 'Kunjungan ke "${widget.item.outletName}" berhasil diselesaikan!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isOffline ? AppColors.secondary : AppColors.tertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
      ),
    );
  }

  void _callOutlet() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Hubungi Outlet?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Melakukan panggilan telepon ke ${widget.item.outletName} di nomor ${widget.item.phone}?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final cleanPhone =
                  widget.item.phone.replaceAll(RegExp(r'[^0-9+]'), '');
              final uri = Uri.parse('tel:$cleanPhone');
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Menghubungi ${widget.item.phone}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Menghubungi ${widget.item.phone}...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.call_rounded, size: 16),
            label: const Text('Panggil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Outlet Header Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.item.initials,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              widget.item.outletName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.item.status == 'Selesai'
                                  ? const Color(0xFFD1F2E2)
                                  : (widget.item.status == 'Sedang Berjalan'
                                      ? const Color(0xFFD8E7FF)
                                      : const Color(0xFFFFE0DB)),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              widget.item.status,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.item.status == 'Selesai'
                                    ? AppColors.tertiary
                                    : (widget.item.status == 'Sedang Berjalan'
                                        ? AppColors.primary
                                        : AppColors.secondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.item.category} • ID: ${widget.item.id}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.item.address,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status Selector Segment (Pending, Selesai, Batal)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              child: Row(
                children: ['Pending', 'Selesai', 'Batal'].map((st) {
                  final isSelected = _currentStatus.toLowerCase() == st.toLowerCase() ||
                      (st == 'Pending' && _currentStatus == 'Pending Sync') ||
                      (st == 'Pending' && _currentStatus == 'Sedang Berjalan') ||
                      (st == 'Pending' && _currentStatus == 'Belum Dikunjungi');
                  Color activeColor;
                  Color activeBg;
                  IconData icon;
                  if (st == 'Selesai') {
                    activeColor = const Color(0xFF006C4C);
                    activeBg = const Color(0xFFC4EED0);
                    icon = Icons.check_circle_rounded;
                  } else if (st == 'Batal') {
                    activeColor = const Color(0xFFBA1A1A);
                    activeBg = const Color(0xFFFFDAD6);
                    icon = Icons.cancel_rounded;
                  } else {
                    activeColor = const Color(0xFF8A5100);
                    activeBg = const Color(0xFFFFEECC);
                    icon = Icons.schedule_rounded;
                  }
                  return Expanded(
                    child: InkWell(
                      onTap: () => _updateStatus(st),
                      borderRadius: BorderRadius.circular(AppRadius.base),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? activeBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.base),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: isSelected ? activeColor : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              st,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? activeColor : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Info Chips Strip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickItem(
                      Icons.navigation_outlined, 'Jarak', widget.item.distance),
                  _buildQuickItem(
                      Icons.timer_outlined, 'Estimasi', widget.item.eta),
                  _buildQuickItem(Icons.gps_fixed_rounded, 'Akurasi GPS', '±3m'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Task Checklist
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Tugas Kunjungan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: _editTaskAndNotes,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Edit Tugas', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (widget.item.task.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.task,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),

            CheckboxListTile(
              value: _taskChecked1,
              onChanged: (val) => setState(() => _taskChecked1 = val ?? false),
              title: Text(
                'Presensi Geotagging & Konfirmasi Lokasi',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: AppColors.primary,
            ),
            CheckboxListTile(
              value: _taskChecked2,
              onChanged: (val) => setState(() => _taskChecked2 = val ?? false),
              title: Text(
                'Dokumentasi Foto Display / Rak Produk',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: AppColors.primary,
            ),
            CheckboxListTile(
              value: _taskChecked3,
              onChanged: (val) => setState(() => _taskChecked3 = val ?? false),
              title: Text(
                'Penyerahan Faktur / Tanda Tangan Digital',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MapScreen(targetVisitId: widget.item.numericId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Buka Peta'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _callOutlet,
                  icon: const Icon(Icons.phone_rounded),
                  color: AppColors.primary,
                  tooltip: 'Telepon Outlet',
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  tooltip: 'Hapus Kunjungan',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Finish Visit CTA
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _markComplete,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  widget.item.status == 'Selesai'
                      ? 'Simpan Ulang Laporan'
                      : 'Tandai Kunjungan Selesai',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tertiary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickItem(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

