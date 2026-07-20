import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../services/barcode_service.dart';
import '../services/tts_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  BarcodeResult? _result;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionTimeoutMs: 3000,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Código de Barras'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _scannerController?.toggleTorch(),
          ),
        ],
      ),
      body: SafeArea(
        child: _result != null ? _buildResultView() : _buildScanner(),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
        _buildScanOverlay(),
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: ElevatedButton.icon(
            onPressed: _digitarCodigoManual,
            icon: const Icon(Icons.keyboard, size: 24),
            label: const Text(
              'DIGITAR NÚMERO DO CÓDIGO',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Identificando medicamento...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white54, size: 48),
              const SizedBox(height: 8),
              Text(
                'Posicione o código de barras\nno centro da tela',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _result != null) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    _consultarCodigo(barcode);
  }

  void _digitarCodigoManual() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Digitar Código de Barras'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite os números (EAN) que aparecem abaixo das barrinhas na embalagem:',
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número do Código',
                hintText: 'Ex: 7891234567890',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final codigo = controller.text.trim();
              if (codigo.isNotEmpty) {
                Navigator.pop(ctx);
                _consultarCodigo(codigo);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Consultar'),
          ),
        ],
      ),
    );
  }

  Future<void> _consultarCodigo(String barcode) async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();
    TTSService.instance.falar('Código capturado, consultando...');

    try {
      final result = await BarcodeService.instance.lookupBarcode(barcode);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isProcessing = false;
      });
      if (result.sucesso) {
        HapticFeedback.heavyImpact();
        TTSService.instance.falar('Código lido: ${result.nome}. ${result.dosagem}');
      } else {
        TTSService.instance.falar('Código não identificado no banco de dados.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = BarcodeResult(erro: 'Erro ao processar: $e');
        _isProcessing = false;
      });
    }
  }

  Widget _buildResultView() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_result!.sucesso) ...[
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Medicamento Identificado!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoCard(),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _result = null;
                        }),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Escanear outro',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, {
                          'titulo': _result!.nome,
                          'dosagem': _result!.dosagem,
                          'barcode': _result!.barcode,
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Usar este', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível identificar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _result!.erro.isNotEmpty
                      ? _result!.erro
                      : 'Código não reconhecido. Tente pela foto.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _result = null;
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente',
                        style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/identify-medication',
                      );
                      if (result != null && mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Ler Embalagem com Inteligência Artificial',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar',
                        style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detalhes identificados:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _ouvirResultado,
                icon: const Icon(Icons.volume_up, size: 18),
                label: const Text('Ouvir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Nome', _result!.nome, onEdit: () => _editarCampo('nome', _result!.nome)),
          _infoRow('Dosagem', _result!.dosagem.isEmpty ? 'Não especificada' : _result!.dosagem, onEdit: () => _editarCampo('dosagem', _result!.dosagem)),
        ],
      ),
    );
  }

  void _ouvirResultado() {
    final result = _result;
    if (result == null || !result.sucesso) return;
    TTSService.instance.parar();
    TTSService.instance.falar('Código lido com sucesso: medicamento ${result.nome}, dosagem ${result.dosagem}');
  }

  void _editarCampo(String campo, String valorAtual) {
    final controller = TextEditingController(text: valorAtual);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar ${campo.toUpperCase()}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: campo,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_result != null) {
                  if (campo == 'nome') {
                    _result = BarcodeResult(
                      barcode: _result!.barcode,
                      nome: controller.text.trim(),
                      dosagem: _result!.dosagem,
                      erro: _result!.erro,
                    );
                  } else if (campo == 'dosagem') {
                    _result = BarcodeResult(
                      barcode: _result!.barcode,
                      nome: _result!.nome,
                      dosagem: controller.text.trim(),
                      erro: _result!.erro,
                    );
                  }
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
              onPressed: onEdit,
              tooltip: 'Editar $label',
            ),
        ],
      ),
    );
  }
}
