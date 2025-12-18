import 'package:flutter/material.dart';

class CubieChatbot extends StatefulWidget {
  final String reportType;
  final Map<String, dynamic>? reportData;
  final Function(String question, String answer)? onQuestionAnswered;

  const CubieChatbot({
    super.key,
    required this.reportType,
    this.reportData,
    this.onQuestionAnswered,
  });

  @override
  State<CubieChatbot> createState() => _CubieChatbotState();
}

class _CubieChatbotState extends State<CubieChatbot>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isTyping = false;
  int _currentQuestionIndex = 0;
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Questions for different report types
  final Map<String, List<QuestionCard>> _reportQuestions = {
    'Sales Trend Report': [
      QuestionCard(
        question: 'What is the total sales for this period?',
        icon: Icons.attach_money,
        color: Color(0xFF4A90A4),
      ),
      QuestionCard(
        question: 'Which store has the highest sales?',
        icon: Icons.store,
        color: Color(0xFF6B8E4E),
      ),
      QuestionCard(
        question: 'What is the best selling category?',
        icon: Icons.category,
        color: Color(0xFFE8A838),
      ),
      QuestionCard(
        question: 'How does this compare to last month?',
        icon: Icons.trending_up,
        color: Color(0xFFD35F5F),
      ),
      QuestionCard(
        question: 'What is the average order value?',
        icon: Icons.receipt_long,
        color: Color(0xFF8E6BB8),
      ),
    ],
    'Discount Report': [
      QuestionCard(
        question: 'What is the total discount given?',
        icon: Icons.discount,
        color: Color(0xFF4A90A4),
      ),
      QuestionCard(
        question: 'Which discount is used most often?',
        icon: Icons.local_offer,
        color: Color(0xFF6B8E4E),
      ),
      QuestionCard(
        question: 'Which store gives the most discounts?',
        icon: Icons.store,
        color: Color(0xFFE8A838),
      ),
      QuestionCard(
        question: 'How many orders had discounts applied?',
        icon: Icons.shopping_cart,
        color: Color(0xFFD35F5F),
      ),
      QuestionCard(
        question: 'What is the average discount per order?',
        icon: Icons.percent,
        color: Color(0xFF8E6BB8),
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Add welcome message
    _messages.add(
      ChatMessage(
        text:
            "Hi! I'm Cubie 🤖\nI can help you understand your ${widget.reportType}. Tap a question below!",
        isBot: true,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void didUpdateWidget(CubieChatbot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportType != widget.reportType) {
      // Reset when report type changes
      setState(() {
        _currentQuestionIndex = 0;
        _messages.clear();
        _messages.add(
          ChatMessage(
            text:
                "Hi! I'm Cubie 🤖\nI can help you understand your ${widget.reportType}. Tap a question below!",
            isBot: true,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<QuestionCard> get _currentQuestions {
    return _reportQuestions[widget.reportType] ??
        _reportQuestions['Sales Trend Report']!;
  }

  void _handleQuestionTap(QuestionCard question) async {
    // Add user question to chat
    setState(() {
      _messages.add(
        ChatMessage(
          text: question.question,
          isBot: false,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate thinking delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Generate answer based on question and report data
    final answer = _generateAnswer(question.question);

    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(text: answer, isBot: true, timestamp: DateTime.now()),
      );
      _currentQuestionIndex++;
    });

    _scrollToBottom();

    // Notify parent
    widget.onQuestionAnswered?.call(question.question, answer);
  }

  String _generateAnswer(String question) {
    final data = widget.reportData;

    if (widget.reportType == 'Sales Trend Report') {
      return _generateSalesAnswer(question, data);
    } else {
      return _generateDiscountAnswer(question, data);
    }
  }

  String _generateSalesAnswer(String question, Map<String, dynamic>? data) {
    if (data == null) {
      return "I don't have enough data to answer that right now. Please make sure the report has loaded.";
    }

    if (question.contains('total sales')) {
      final total = data['totalSales'] ?? data['total'] ?? 0;
      return "📊 The total sales for this period is \$${_formatNumber(total)}. That's looking great!";
    } else if (question.contains('highest sales')) {
      final topStore = data['topStore'] ?? 'Not available';
      final storeAmount = data['topStoreAmount'] ?? 0;
      return "🏆 $topStore leads with \$${_formatNumber(storeAmount)} in sales! They're crushing it!";
    } else if (question.contains('best selling category')) {
      final topCategory = data['topCategory'] ?? 'Not available';
      final categoryAmount = data['topCategoryAmount'] ?? 0;
      return "⭐ $topCategory is your best seller with \$${_formatNumber(categoryAmount)}! Keep stocking up!";
    } else if (question.contains('compare to last month')) {
      final growth = data['monthlyGrowth'] ?? 0;
      final emoji = growth >= 0 ? '📈' : '📉';
      return "$emoji Sales are ${growth >= 0 ? 'up' : 'down'} ${growth.abs().toStringAsFixed(1)}% compared to last month.";
    } else if (question.contains('average order')) {
      final avgOrder = data['averageOrder'] ?? 0;
      return "🧾 The average order value is \$${_formatNumber(avgOrder)}. Consider upselling to increase this!";
    }

    return "That's a great question! Based on your data, things are looking positive. Check the charts for more details.";
  }

  String _generateDiscountAnswer(String question, Map<String, dynamic>? data) {
    if (data == null) {
      return "I don't have enough data to answer that right now. Please make sure the report has loaded.";
    }

    if (question.contains('total discount')) {
      final total = data['totalDiscount'] ?? 0;
      return "💰 The total discount given is \$${_formatNumber(total)}. Make sure it's driving sales!";
    } else if (question.contains('used most often')) {
      final topDiscount = data['topDiscount'] ?? 'Not available';
      final times = data['topDiscountTimes'] ?? 0;
      return "🎯 '$topDiscount' is your most popular discount, used $times times!";
    } else if (question.contains('most discounts')) {
      final topStore = data['topDiscountStore'] ?? 'Not available';
      final amount = data['topDiscountStoreAmount'] ?? 0;
      return "🏪 $topStore has given the most discounts totaling \$${_formatNumber(amount)}.";
    } else if (question.contains('orders had discounts')) {
      final orders = data['ordersWithDiscount'] ?? 0;
      return "🛒 $orders orders had discounts applied in this period.";
    } else if (question.contains('average discount')) {
      final avgDiscount = data['averageDiscount'] ?? 0;
      return "📊 The average discount per order is \$${_formatNumber(avgDiscount)}.";
    }

    return "Great question! Your discount strategy seems to be working. Check the breakdown charts for more insights.";
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) {
      return value
          .toStringAsFixed(2)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return value.toString();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chat panel
        if (_isExpanded)
          Positioned(right: 20, bottom: 90, child: _buildChatPanel()),
        // Floating button
        Positioned(
          right: 20,
          bottom: 20,
          child: AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _isExpanded ? 0 : -_bounceAnimation.value),
                child: child,
              );
            },
            child: _buildFloatingButton(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF4A90A4), const Color(0xFF1E5F8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E5F8A).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              _isExpanded ? Icons.close : Icons.smart_toy,
              color: Colors.white,
              size: 28,
            ),
            if (!_isExpanded &&
                _currentQuestionIndex < _currentQuestions.length)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 360,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Messages
            Expanded(child: _buildMessageList()),
            // Question cards
            if (_currentQuestionIndex < _currentQuestions.length)
              _buildQuestionCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4A90A4), const Color(0xFF1E5F8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cubie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.reportType,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _currentQuestionIndex = 0;
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text:
                        "Hi! I'm Cubie 🤖\nI can help you understand your ${widget.reportType}. Tap a question below!",
                    isBot: true,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Start Over',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: message.isBot ? Colors.grey[100] : const Color(0xFF1E5F8A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isBot ? 4 : 16),
            bottomRight: Radius.circular(message.isBot ? 16 : 4),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isBot ? Colors.black87 : Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_buildDot(0), _buildDot(1), _buildDot(2)],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 150)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[400],
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildQuestionCards() {
    final remainingQuestions = _currentQuestions
        .skip(_currentQuestionIndex)
        .take(2)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested Questions:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...remainingQuestions.map((q) => _buildQuestionCardItem(q)),
        ],
      ),
    );
  }

  Widget _buildQuestionCardItem(QuestionCard question) {
    return GestureDetector(
      onTap: () => _handleQuestionTap(question),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: question.color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: question.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(question.icon, color: question.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                question.question,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
  });
}

class QuestionCard {
  final String question;
  final IconData icon;
  final Color color;

  QuestionCard({
    required this.question,
    required this.icon,
    required this.color,
  });
}
