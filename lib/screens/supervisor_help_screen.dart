import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';

class FAQItem {
  final String category;
  final String question;
  final String answer;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class SupervisorHelpScreen extends StatefulWidget {
  const SupervisorHelpScreen({super.key});

  @override
  State<SupervisorHelpScreen> createState() => _SupervisorHelpScreenState();
}

class _SupervisorHelpScreenState extends State<SupervisorHelpScreen> {
  String _searchQuery = '';

  final List<FAQItem> _faqs = [
    // Gerenciar Lembretes
    FAQItem(
      category: 'Gerenciar Lembretes',
      question: 'Como cadastrar um lembrete com áudio familiar?',
      answer:
          'Ao criar um lembrete, selecione "Grave Voz" na seção "Áudio do Idoso" e use o microfone para gravar uma frase curta e familiar. Essa gravação tocará no celular do idoso logo no início do aviso.',
    ),
    FAQItem(
      category: 'Gerenciar Lembretes',
      question: 'Como associar a foto real do remédio?',
      answer:
          'Selecione a categoria "Remédio" e toque na área "Tirar Foto do Remédio". Capture a embalagem ou comprimido para que o idoso consiga identificá-lo visualmente com facilidade.',
    ),
    // Histórico e Relatórios
    FAQItem(
      category: 'Histórico e Relatórios',
      question: 'Como conferir se o idoso tomou o remédio correto?',
      answer:
          'Acesse a tela "Histórico" no menu inferior. Se o lembrete foi concluído com foto, você verá um botão "Ver Foto". Toque nele para abrir a imagem de confirmação tirada pelo idoso.',
    ),
    FAQItem(
      category: 'Histórico e Relatórios',
      question: 'Como visualizar os relatórios de adesão mensal?',
      answer:
          'Clique em "Relatórios Mensais" no menu lateral (Drawer) ou no botão correspondente no histórico para ver gráficos coloridos de cumprimento da rotina do idoso.',
    ),
    // Monitoramento de Saúde
    FAQItem(
      category: 'Monitoramento de Saúde',
      question: 'O que significa o indicador de bateria no painel?',
      answer:
          'Representa a carga atual da bateria do celular do idoso. Se o nível cair abaixo de 15%, um alerta de bateria baixa será destacado no radar do cuidador.',
    ),
    // Alertas de Emergência
    FAQItem(
      category: 'Alertas de Emergência',
      question: 'Como funciona o botão de socorro do idoso?',
      answer:
          'Quando o idoso pressiona o botão "SOS" na tela dele, a central do cuidador recebe instantaneamente um alerta crítico vermelho e toca uma sirene de emergência.',
    ),
    FAQItem(
      category: 'Alertas de Emergência',
      question: 'O que são as barreiras do "Radar do Celular"?',
      answer:
          'São alertas automatizados baseados em sensores. Por exemplo, se o volume do idoso estiver no mínimo ou se o app estiver inativo, o cuidador será avisado.',
    ),
    // Configurações Gerais
    FAQItem(
      category: 'Configurações Gerais',
      question: 'Como edito a foto ou as informações do paciente?',
      answer:
          'Você pode editar o perfil do paciente, incluindo foto e dados pessoais, acessando o menu lateral e selecionando a opção de edição de perfil.',
    ),
    FAQItem(
      category: 'Configurações Gerais',
      question: 'Como configurar as opções de voz (Alex) para o idoso?',
      answer:
          'Para configurar a voz e leitura de tela, acesse o menu lateral, vá em "Configurações de Voz" e personalize a assistente virtual de acordo com a preferência do idoso.',
    ),
    // Chamadas
    FAQItem(
      category: 'Monitoramento de Saúde',
      question: 'Como funcionam as chamadas de vídeo e áudio?',
      answer:
          'Através do painel principal, você pode iniciar chamadas de vídeo ou áudio para se comunicar com o idoso de forma simples e rápida, permitindo verificar como ele está em tempo real.',
    ),
  ];

  void _showQuickTour(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        int currentSlide = 0;
        final slides = [
          {
            'title': '1. Emparelhamento',
            'desc':
                'Vincule o celular do idoso na opção "Cadastrar/Emparelhar Idoso" do menu lateral para que a sincronização comece de imediato.',
            'icon': Icons.phonelink_setup,
            'color': AppColors.primary,
          },
          {
            'title': '2. Criar Lembretes',
            'desc':
                'Configure remédios, refeições ou hidratação. Grave sua própria voz e tire foto real do remédio para ajudar na identificação.',
            'icon': Icons.add_circle_outline,
            'color': AppColors.secondary,
          },
          {
            'title': '3. Monitoramento & SOS',
            'desc':
                'Acompanhe a bateria e alertas do radar. Se o idoso pedir ajuda (SOS), você receberá um aviso sonoro imediato.',
            'icon': Icons.warning_amber,
            'color': AppColors.error,
          },
        ];

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final slide = slides[currentSlide];
            final slideColor = slide['color'] as Color;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Guia de Início Rápido',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: slideColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        slide['icon'] as IconData,
                        size: 64,
                        color: slideColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slide['title'] as String,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: slideColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide['desc'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Navigation Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (idx) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentSlide == idx
                                ? slideColor
                                : AppColors.outlineVariant,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: currentSlide == 0
                              ? null
                              : () {
                                  setStateDialog(() {
                                    currentSlide--;
                                  });
                                },
                          child: const Text(
                            'VOLTAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (currentSlide < slides.length - 1) {
                              setStateDialog(() {
                                currentSlide++;
                              });
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: slideColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            currentSlide == slides.length - 1
                                ? 'CONCLUIR'
                                : 'AVANÇAR',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchUrlHelper(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter FAQs based on query
    var filteredFaqs = _faqs;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredFaqs = _faqs
          .where(
            (f) =>
                f.question.toLowerCase().contains(query) ||
                f.answer.toLowerCase().contains(query) ||
                f.category.toLowerCase().contains(query),
          )
          .toList();
    }

    // Group filtered FAQs by Category
    final Map<String, List<FAQItem>> groupedFaqs = {};
    for (final faq in filteredFaqs) {
      groupedFaqs.putIfAbsent(faq.category, () => []).add(faq);
    }

    final categoriesMetadata = {
      'Gerenciar Lembretes': {
        'icon': Icons.medication,
        'color': AppColors.medicationsColor,
      },
      'Histórico e Relatórios': {
        'icon': Icons.history,
        'color': AppColors.mealsColor,
      },
      'Monitoramento de Saúde': {
        'icon': Icons.favorite,
        'color': AppColors.tertiaryContainer,
      },
      'Alertas de Emergência': {
        'icon': Icons.warning_amber,
        'color': AppColors.error,
      },
      'Configurações Gerais': {
        'icon': Icons.settings,
        'color': AppColors.primary,
      },
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/supervisor-help'),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.help,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Tour Banner
                    GestureDetector(
                      onTap: () => _showQuickTour(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Novo no Lembrete Amigo?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Veja o Guia de Início Rápido (3 passos)',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Central de Ajuda',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tire dúvidas sobre o painel do cuidador.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search box
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        border: Border.all(color: AppColors.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Pesquisar dúvidas...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // FAQ List
                    if (groupedFaqs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.help_outline,
                                size: 64,
                                color: AppColors.outlineVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma dúvida encontrada',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...groupedFaqs.entries.map((group) {
                        final catName = group.key;
                        final items = group.value;
                        final meta =
                            categoriesMetadata[catName] ??
                            {'icon': Icons.help, 'color': AppColors.primary};
                        final catIcon = meta['icon'] as IconData;
                        final catColor = meta['color'] as Color;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(catIcon, color: catColor, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      catName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: catColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              ...items.map((item) {
                                return Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Text(
                                      item.question,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    childrenPadding: const EdgeInsets.only(
                                      bottom: 12,
                                      left: 8,
                                      right: 8,
                                    ),
                                    children: [
                                      Text(
                                        item.answer,
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.45,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    // Technical Support Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.support_agent,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Suporte Técnico',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Precisa de ajuda adicional? Fale com nossa equipe diretamente através das opções de contato rápido:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _launchUrlHelper(
                                    'https://wa.me/5586994194571?text=Olá,%20preciso%20de%20ajuda%20com%20o%20app%20Lembrete%20Amigo.',
                                  ),
                                  icon: const Icon(Icons.forum, size: 20),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('WhatsApp'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _launchUrlHelper('tel:+5586994194571'),
                                  icon: const Icon(Icons.phone, size: 20),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Ligar'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _launchUrlHelper(
                                    'mailto:guilhermebarbosa556@gmail.com?subject=Ajuda%20Lembrete%20Amigo',
                                  ),
                                  icon: const Icon(Icons.email, size: 20),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('E-mail'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Builder(
      builder: (context) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: AppColors.surface),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu, color: AppColors.primary, size: 32),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.health_and_safety,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cuidador',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        );
      },
    );
  }
}
