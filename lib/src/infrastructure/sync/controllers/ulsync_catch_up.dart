/// Простая машина догонки: есть работа — гоняем обмен до тишины.
///
/// Состояния:
/// - [idle] — делать нечего;
/// - [due] — нужен ещё один обмен;
/// - [running] — обмен идёт.
///
/// Правило одно. Кто угодно говорит «есть работа» через [run]. Если обмен
/// уже идёт, новый вызов **ждёт** и после текущего круга будет ещё один.
/// Чужой обмен не засчитываем как свой: работу не выкидываем.
library;

/// Пауза подстраховки, пока приложение на экране.
///
/// Та же 3 секунды, что у живой ленты между стуками: в тишине ещё раз
/// спрашиваем сервер, мало ли конверт не доехал по SSE.
const Duration kUlsyncCatchUpSafetyInterval = Duration(seconds: 3);

/// Состояние машины догонки.
enum UlsyncCatchUpState {
  /// Обмен не нужен.
  idle,

  /// Нужно вызвать обмен.
  due,

  /// Обмен сейчас идёт.
  running,
}

/// Очередь обменов: [run] до тех пор, пока не станет тихо.
final class UlsyncCatchUp {
  UlsyncCatchUpState _state = UlsyncCatchUpState.idle;

  /// Кто-то попросил ещё круг, пока текущий [running].
  bool _again = false;

  /// Что гонять. Последний [run] перезаписывает: все зовут один и тот же обмен.
  Future<void> Function()? _work;

  /// Текущий проход до тишины; ждут все [run].
  Future<void>? _inFlight;

  /// Сейчас: тихо, надо, или идёт.
  UlsyncCatchUpState get state => _state;

  /// Ставит работу в очередь и ждёт, пока машина не дойдёт до [idle].
  ///
  /// Ошибку видит тот вызов, который вёл круг. Остальные ждут следующий
  /// круг или тишину и чужой сбой не пробрасывают.
  Future<void> run(Future<void> Function() work) async {
    _work = work;
    _request();
    while (_state != UlsyncCatchUpState.idle) {
      final existing = _inFlight;
      if (existing != null) {
        try {
          await existing;
        } on Object {
          // Ведущий круг залогирует. Нам нужно не уйти, пока есть работа.
        }
        continue;
      }
      if (_state == UlsyncCatchUpState.idle) {
        return;
      }
      final mine = _drain();
      _inFlight = mine;
      try {
        await mine;
        return;
      } on Object {
        if (_state == UlsyncCatchUpState.due) {
          continue;
        }
        rethrow;
      }
    }
  }

  void _request() {
    switch (_state) {
      case UlsyncCatchUpState.idle:
        _state = UlsyncCatchUpState.due;
      case UlsyncCatchUpState.due:
        break;
      case UlsyncCatchUpState.running:
        _again = true;
    }
  }

  Future<void> _drain() async {
    try {
      while (_state == UlsyncCatchUpState.due) {
        _state = UlsyncCatchUpState.running;
        _again = false;
        final work = _work;
        if (work == null) {
          _state = UlsyncCatchUpState.idle;
          return;
        }
        try {
          await work();
        } catch (e, st) {
          _state = _again ? UlsyncCatchUpState.due : UlsyncCatchUpState.idle;
          _again = false;
          Error.throwWithStackTrace(e, st);
        }
        _state = _again ? UlsyncCatchUpState.due : UlsyncCatchUpState.idle;
      }
    } finally {
      _inFlight = null;
    }
  }
}
