import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lembrete.dart';
import 'notification_service.dart';

class LembreteService {
  LembreteService._();
  static final LembreteService _instance = LembreteService._();
  static LembreteService get instance => _instance;

  final List<Lembrete> _lembretes = [];
  final ValueNotifier<List<Lembrete>> notifier = ValueNotifier([]);
  bool _loaded = false;

  List<Lembrete> get lembretes => List.unmodifiable(_lembretes);

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getActiveIdosoId() async {
    final prefs = await SharedPreferences.getInstance();
    final supervisorActive = prefs.getString('selected_idoso_id');
    final elderlyActive = prefs.getString('paired_idoso_id');
    return supervisorActive ?? elderlyActive ?? 'joao';
  }

  Future<void> carregar() async {
    if (_loaded) return;
    _loaded = true;

    if (_useFirebase) {
      final idosoId = await _getActiveIdosoId();
      FirebaseFirestore.instance
          .collection('lembretes')
          .where('idosoId', isEqualTo: idosoId)
          .snapshots()
          .listen((snapshot) {
        _lembretes.clear();
        for (var doc in snapshot.docs) {
          _lembretes.add(Lembrete.fromJson(doc.data()));
        }
        // Sort locally by criadoEm descending to avoid firestore index creation requirement
        _lembretes.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
        notifier.value = List.from(_lembretes);
        NotificationService.instance.agendarTodos(_lembretes);
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('lembretes');
      if (data != null) {
        final list = jsonDecode(data) as List;
        _lembretes.addAll(list.map((e) => Lembrete.fromJson(e as Map<String, dynamic>)));
      }
      notifier.value = List.from(_lembretes);
      NotificationService.instance.agendarTodos(_lembretes);
    }
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_lembretes.map((l) => l.toJson()).toList());
    await prefs.setString('lembretes', data);
    notifier.value = List.from(_lembretes);
    NotificationService.instance.agendarTodos(_lembretes);
  }

  Future<void> adicionar(Lembrete lembrete) async {
    String novoTitulo = lembrete.titulo;
    if (novoTitulo.isNotEmpty) {
      novoTitulo = novoTitulo[0].toUpperCase() + novoTitulo.substring(1);
    }
    final idosoId = await _getActiveIdosoId();
    final lembreteCapitalizado = Lembrete(
      id: lembrete.id,
      titulo: novoTitulo,
      horarioHour: lembrete.horarioHour,
      horarioMinute: lembrete.horarioMinute,
      categoria: lembrete.categoria,
      audioPath: lembrete.audioPath,
      concluido: lembrete.concluido,
      concluidoComFoto: lembrete.concluidoComFoto,
      criadoEm: lembrete.criadoEm,
      medicamentoForma: lembrete.medicamentoForma,
      medicamentoCor: lembrete.medicamentoCor,
      medicamentoFotoPath: lembrete.medicamentoFotoPath,
      idosoId: idosoId,
    );

    if (_useFirebase) {
      await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(lembreteCapitalizado.id)
          .set(lembreteCapitalizado.toJson());
    } else {
      _lembretes.add(lembreteCapitalizado);
      await _salvar();
    }
  }

  Future<void> concluir(String id) async {
    if (_useFirebase) {
      await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(id)
          .update({'concluido': true});
    } else {
      final idx = _lembretes.indexWhere((l) => l.id == id);
      if (idx != -1) {
        _lembretes[idx] = Lembrete(
          id: _lembretes[idx].id,
          titulo: _lembretes[idx].titulo,
          horarioHour: _lembretes[idx].horarioHour,
          horarioMinute: _lembretes[idx].horarioMinute,
          categoria: _lembretes[idx].categoria,
          audioPath: _lembretes[idx].audioPath,
          concluido: true,
          concluidoComFoto: _lembretes[idx].concluidoComFoto,
          criadoEm: _lembretes[idx].criadoEm,
          medicamentoForma: _lembretes[idx].medicamentoForma,
          medicamentoCor: _lembretes[idx].medicamentoCor,
          medicamentoFotoPath: _lembretes[idx].medicamentoFotoPath,
          idosoId: _lembretes[idx].idosoId,
        );
        await _salvar();
      }
    }
  }

  Future<void> concluirComFoto(String id) async {
    if (_useFirebase) {
      await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(id)
          .update({'concluido': true, 'concluidoComFoto': true});
    } else {
      final idx = _lembretes.indexWhere((l) => l.id == id);
      if (idx != -1) {
        _lembretes[idx] = Lembrete(
          id: _lembretes[idx].id,
          titulo: _lembretes[idx].titulo,
          horarioHour: _lembretes[idx].horarioHour,
          horarioMinute: _lembretes[idx].horarioMinute,
          categoria: _lembretes[idx].categoria,
          audioPath: _lembretes[idx].audioPath,
          concluido: true,
          concluidoComFoto: true,
          criadoEm: _lembretes[idx].criadoEm,
          medicamentoForma: _lembretes[idx].medicamentoForma,
          medicamentoCor: _lembretes[idx].medicamentoCor,
          medicamentoFotoPath: _lembretes[idx].medicamentoFotoPath,
          idosoId: _lembretes[idx].idosoId,
        );
        await _salvar();
      }
    }
  }

  Future<void> alternarConclusao(String id) async {
    if (_useFirebase) {
      final doc = await FirebaseFirestore.instance.collection('lembretes').doc(id).get();
      if (doc.exists) {
        final atualConcluido = doc.data()?['concluido'] as bool? ?? false;
        await FirebaseFirestore.instance
            .collection('lembretes')
            .doc(id)
            .update({
          'concluido': !atualConcluido,
          'concluidoComFoto': !atualConcluido ? (doc.data()?['concluidoComFoto'] as bool? ?? false) : false
        });
      }
    } else {
      final idx = _lembretes.indexWhere((l) => l.id == id);
      if (idx != -1) {
        final novoConcluido = !_lembretes[idx].concluido;
        _lembretes[idx] = Lembrete(
          id: _lembretes[idx].id,
          titulo: _lembretes[idx].titulo,
          horarioHour: _lembretes[idx].horarioHour,
          horarioMinute: _lembretes[idx].horarioMinute,
          categoria: _lembretes[idx].categoria,
          audioPath: _lembretes[idx].audioPath,
          concluido: novoConcluido,
          concluidoComFoto: novoConcluido ? _lembretes[idx].concluidoComFoto : false,
          criadoEm: _lembretes[idx].criadoEm,
          medicamentoForma: _lembretes[idx].medicamentoForma,
          medicamentoCor: _lembretes[idx].medicamentoCor,
          medicamentoFotoPath: _lembretes[idx].medicamentoFotoPath,
          idosoId: _lembretes[idx].idosoId,
        );
        await _salvar();
      }
    }
  }

  Future<void> remover(String id) async {
    if (_useFirebase) {
      await FirebaseFirestore.instance.collection('lembretes').doc(id).delete();
    } else {
      _lembretes.removeWhere((l) => l.id == id);
      await _salvar();
    }
  }

  Future<void> atualizarHorario(String id, int hour, int minute) async {
    if (_useFirebase) {
      await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(id)
          .update({'horarioHour': hour, 'horarioMinute': minute});
    } else {
      final idx = _lembretes.indexWhere((l) => l.id == id);
      if (idx != -1) {
        _lembretes[idx] = Lembrete(
          id: _lembretes[idx].id,
          titulo: _lembretes[idx].titulo,
          horarioHour: hour,
          horarioMinute: minute,
          categoria: _lembretes[idx].categoria,
          audioPath: _lembretes[idx].audioPath,
          concluido: _lembretes[idx].concluido,
          concluidoComFoto: _lembretes[idx].concluidoComFoto,
          criadoEm: _lembretes[idx].criadoEm,
          medicamentoForma: _lembretes[idx].medicamentoForma,
          medicamentoCor: _lembretes[idx].medicamentoCor,
          medicamentoFotoPath: _lembretes[idx].medicamentoFotoPath,
          idosoId: _lembretes[idx].idosoId,
        );
        await _salvar();
      }
    }
  }

  Future<void> adiar(String id, int minutos) async {
    final now = DateTime.now().add(Duration(minutes: minutos));
    if (_useFirebase) {
      await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(id)
          .update({'horarioHour': now.hour, 'horarioMinute': now.minute});
    } else {
      final idx = _lembretes.indexWhere((l) => l.id == id);
      if (idx != -1) {
        _lembretes[idx] = Lembrete(
          id: _lembretes[idx].id,
          titulo: _lembretes[idx].titulo,
          horarioHour: now.hour,
          horarioMinute: now.minute,
          categoria: _lembretes[idx].categoria,
          audioPath: _lembretes[idx].audioPath,
          concluido: _lembretes[idx].concluido,
          concluidoComFoto: _lembretes[idx].concluidoComFoto,
          criadoEm: _lembretes[idx].criadoEm,
          medicamentoForma: _lembretes[idx].medicamentoForma,
          medicamentoCor: _lembretes[idx].medicamentoCor,
          medicamentoFotoPath: _lembretes[idx].medicamentoFotoPath,
          idosoId: _lembretes[idx].idosoId,
        );
        await _salvar();
      }
    }
  }
}
