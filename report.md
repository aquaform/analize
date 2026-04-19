# Отчёт по аудиту смарт-контрактов UpgradableCalculator

Аудит выполнен по Модулю В. Анализируемые файлы: [ACalculator.sol](ACalculator.sol), [Calculator.sol](Calculator.sol), [CalculatorCaller.sol](CalculatorCaller.sol).

Исправленные контракты лежат в [fixed/](fixed/), автоматизированные тесты — в [test/](test/).

---

## 1. Отчёт по синтаксису

Ошибки, из-за которых исходник не компилируется в Solidity 0.8.20.

| № | Файл | Строка | Ошибка | Исправление |
|---|---|---|---|---|
| С1 | CalculatorCaller.sol | 2 | `pragmа` — буква `а` кириллическая (U+0430) | `pragma solidity ^0.8.20;` |
| С2 | CalculatorCaller.sol | 4 | `import {ACalculator, ACalculator.Version as Version}` — переименование вложенного типа в import не поддерживается | `import {ACalculator} from "./ACalculator.sol";` |
| С3 | CalculatorCaller.sol | 53 | Нет открывающей `{` у функции `_getUserSelectedVersion` | Добавить `{` после `returns(address selectedAddress)` |
| С4 | CalculatorCaller.sol | 54 | `memory string userVersion = …` — обратный порядок модификатора и типа | `string memory userVersion = userSelectedVersion[user];` |
| С5 | CalculatorCaller.sol | 121 | У `callMultiple` нет закрывающей `}`; из-за этого `callDivision` оказывается вложенной функцией | Поставить `}` после `return result;` в `callMultiple` |
| С6 | CalculatorCaller.sol | 130 | `emit newLatestVersion(address calculator, string memory version);` в теле контракта — это попытка объявить событие, но через `emit`. `emit` — оператор внутри функции, не декларация | Заменить на `event newLatestVersion(address indexed calculator, string version);` и перенести в начало тела контракта |
| С7 | CalculatorCaller.sol | 89 | `emit newLatestVersion(newCalculator, v);` — на момент этой строки событие `newLatestVersion` не объявлено (см. С6), компиляция падает на неопределённом идентификаторе | Восстанавливается после С6 |
| С8 | CalculatorCaller.sol | 38, 50 | `supportCalculatorCreator` не помечена `payable`, но читает `msg.value` и пытается переслать его. При ненулевом `msg.value` вызов не проходит | Добавить модификатор `payable`: `function supportCalculatorCreator(address calculator) external payable` |
| С9 | CalculatorCaller.sol | 8–11 | У переменных состояния `calculators`, `userSelectedVersion`, `lastVersion`, `owner` не задана видимость (неявно `internal`) — нарушает style guide, большинство линтеров/компилятор с `-Werror` отклоняют | Явно указать видимость (`private` / `public`) |
| С10 | CalculatorCaller.sol | 131 | После фиксации С5 и С6 у контракта повисает несбалансированная `}` — итоговую закрывающую скобку нужно восстановить | Закрыть контракт `}` после переноса события |

---

## 2. Отчёт по функционалу (NatSpec)

Ниже — функциональное описание каждого контракта в формате NatSpec. Применено к исправленной версии; принципы работы те же.

### ACalculator.sol

```solidity
/// @title ACalculator
/// @notice Абстрактный интерфейс калькулятора. Задаёт обязательный набор арифметических
///         операций и способ получения версии/автора конкретной реализации.
/// @dev Наследуется всеми конкретными реализациями калькулятора. Используется
///      роутером CalculatorCaller для унифицированных внешних вызовов.
abstract contract ACalculator {
    /// @notice Строгая версионная структура (SemVer: main.sub.temp).
    /// @param version     Отформатированная строка вида "1.0.0" — ключ в реестре.
    /// @param mainVersion Старшая часть версии.
    /// @param subVersion  Средняя часть версии.
    /// @param tempVersion Младшая (patch) часть версии.
    struct Version { string version; uint8 mainVersion; uint8 subVersion; uint8 tempVersion; }

    /// @notice Возвращает адрес деплоера/автора контракта.
    function getCreator() external virtual view returns(address);

    /// @notice Возвращает версию реализации.
    function getVersion() external virtual view returns(Version memory);

    /// @notice Сложение двух беззнаковых целых.
    function add(uint a, uint b) external virtual pure returns(uint);

    /// @notice Вычитание b из a.
    function minus(uint a, uint b) external virtual pure returns(uint);

    /// @notice Умножение.
    function multiple(uint a, uint b) external virtual pure returns(uint);

    /// @notice Целочисленное деление a на b.
    function division(uint a, uint b) external virtual pure returns(uint);
}
```

### Calculator.sol

```solidity
/// @title Calculator
/// @notice Конкретная реализация ACalculator с фиксированной версией, заданной в конструкторе.
/// @dev Хранит автора (creator) и структуру Version. Строковое представление версии
///      формируется конкатенацией трёх uint8-значений через ".".
contract Calculator is ACalculator {

    /// @notice Конструктор формирует строку версии и сохраняет автора.
    /// @param _first Старшая часть версии (major).
    /// @param _sub   Средняя часть версии (minor).
    /// @param _temp  Младшая часть версии (patch).
    constructor(uint8 _first, uint8 _sub, uint8 _temp);

    /// @notice Возвращает автора контракта.
    function getCreator() external view returns(address);

    /// @dev Преобразование uint256 в десятичную строку. Используется в конструкторе.
    function uintToString(uint256 value) internal pure returns (string memory);

    /// @notice Арифметические операции. Division revert-ит при делении на ноль.
    function add(uint a, uint b) external pure returns(uint);
    function multiple(uint a, uint b) external pure returns(uint);
    function division(uint a, uint b) external pure returns(uint);
    function minus(uint a, uint b) external pure returns(uint);

    /// @notice Возвращает версию калькулятора.
    function getVersion() external view returns(Version memory);
}
```

### CalculatorCaller.sol

```solidity
/// @title CalculatorCaller
/// @notice Роутер/реестр версий калькуляторов. Хранит отображение строковой версии
///         в адрес реализации, позволяет пользователю выбирать активную версию,
///         перенаправляет арифметические вызовы на выбранный калькулятор и
///         управляет пожертвованиями авторам реализаций.
/// @dev Владелец — развернувший контракт. Регистрация новых калькуляторов
///      в исходнике публична (см. раздел «ИБ»), чтение — через getCalculator.
contract CalculatorCaller {

    /// @notice Событие выпуска новой последней версии.
    /// @param calculator Адрес добавленной реализации.
    /// @param version    Строковая версия.
    event newLatestVersion(address calculator, string version);

    /// @notice Инициализация реестра первым калькулятором.
    /// @param firstCalculator Адрес уже развёрнутого Calculator-а.
    constructor(address firstCalculator);

    /// @notice Переводит ETH на произвольный адрес (утилита).
    /// @param to Получатель средств.
    function fund(address payable to) external payable;

    /// @notice Вывод всего баланса владельцу.
    function take() external;

    /// @notice Отправить msg.value автору зарегистрированного калькулятора.
    /// @param calculator Адрес зарегистрированной реализации.
    function supportCalculatorCreator(address calculator) external;

    /// @dev Возвращает адрес калькулятора, выбранного пользователем, либо последний.
    function _getUserSelectedVersion(address user) internal view returns(address);

    /// @notice Установить активную версию для msg.sender.
    /// @param _version Строка версии из реестра. Пустая строка сбрасывает выбор.
    /// @return currentAddress Адрес, выбранный после вызова.
    function changeSelectedVersion(string calldata _version) external returns (address);

    /// @notice Регистрация новой реализации калькулятора.
    /// @param newCalculator Адрес новой реализации.
    function addNewCalculator(address newCalculator) external;

    /// @notice Получить адрес по строке версии.
    function getCalculator(string calldata _version) external view returns(address);

    /// @notice Прокси-вызовы арифметики на выбранной пользователем версии.
    function callAdd(uint a, uint b) external returns(uint);
    function callMinus(uint a, uint b) external returns(uint);
    function callMultiple(uint a, uint b) external returns(uint);
    function callDivision(uint a, uint b) external returns(uint);
}
```

---

## 3. Отчёт по логике

Ошибки, которые компилируются (либо компилировались бы после правки синтаксиса), но ломают работу.

### 3.1 `_getUserSelectedVersion` — неверное условие выбора версии

**Файл:** CalculatorCaller.sol:56

```solidity
if (bytes(userVersion).length < 0 && calculators[userVersion] != address(0))
```

`length` — `uint`, сравнение `< 0` никогда не истинно, ветка никогда не выполняется → пользователь **всегда** получает `lastVersion`, даже если явно выбрал другую.

**Исправление:** `bytes(userVersion).length > 0`.

### 3.2 `changeSelectedVersion` — инвертированная тернарка возврата

**Файл:** CalculatorCaller.sol:66

```solidity
currentAddress = isFind == false ? calculators[_version] : calculators[lastVersion.version];
```

Если версия найдена (`isFind == true`), возвращается адрес **последней** версии, а не выбранной. Если не найдена — адрес нулевой версии.

**Исправление:**

```solidity
currentAddress = isFind ? calculators[_version] : calculators[lastVersion.version];
```

### 3.3 `addNewCalculator` — неверная проверка возрастания версии

**Файл:** CalculatorCaller.sol:84–86

```solidity
if (v1 > last.mainVersion ||
    (v1 == last.mainVersion && v2 > last.subVersion) ||
    (v1 != last.mainVersion && v2 == last.subVersion && v3 > last.tempVersion))
```

В третьей ветви стоит `v1 != last.mainVersion`, а должно быть `v1 == last.mainVersion && v2 == last.subVersion`. При равных major/minor и большем patch условие не срабатывает → revert, новая patch-версия не регистрируется.

**Исправление:**

```solidity
v1 > last.mainVersion ||
(v1 == last.mainVersion && v2 > last.subVersion) ||
(v1 == last.mainVersion && v2 == last.subVersion && v3 > last.tempVersion)
```

### 3.4 `addNewCalculator` — старая версия не регистрируется

При добавлении более старой (но валидной) версии происходит `revert`, хотя `calculators[v] = newCalculator;` уже произошло строкой выше. Из-за revert состояние откатывается, и зарегистрировать старую версию невозможно в принципе.

**Исправление:** не ревертить; если версия не выше последней — просто пропустить обновление `lastVersion` и не эмитить `newLatestVersion`, но калькулятор в реестр добавить.

### 3.5 `callAdd` — опечатка в сигнатуре

**Файл:** CalculatorCaller.sol:101

```solidity
abi.encodeWithSignature("ad(uint256,uint256)", a, b)
```

Ищется функция `ad`, которой нет → вызов всегда ревертит с `"error add call"`.

**Исправление:** `"add(uint256,uint256)"` или `abi.encodeWithSelector(ACalculator.add.selector, a, b)`.

### 3.6 `callMinus` — пробел в сигнатуре

**Файл:** CalculatorCaller.sol:109

```solidity
abi.encodeWithSignature("minus(uint256, uint256)", a, b)
```

Селектор считается по байтам сигнатуры без нормализации; пробел ломает keccak-хеш → функция не находится.

**Исправление:** `"minus(uint256,uint256)"`.

### 3.7 `callMultiple` — используется селектор `add`

**Файл:** CalculatorCaller.sol:117

```solidity
abi.encodeWithSelector(ACalculator.add.selector, a, b)
```

Умножение вызывает `add` → `callMultiple(2, 3) == 5`.

**Исправление:** `ACalculator.multiple.selector`.

### 3.8 `callDivision` — инверсия проверки успеха

**Файл:** CalculatorCaller.sol:125

```solidity
require(!success, "error division call");
```

Требует, чтобы вызов **провалился**. При нормальном делении функция ревертит.

**Исправление:** `require(success, "error division call");`.

### 3.9 `take` — tx.origin

**Файл:** CalculatorCaller.sol:32

`require(tx.origin == owner, "only owner")` — разрешает вывод через транзакцию, инициированную владельцем, даже если её отправляет **другой контракт**. Любой контракт, к которому владелец обратится, сможет вызвать `take()` из своего кода.

**Исправление:** `require(msg.sender == owner, "only owner");`.

### 3.10 `supportCalculatorCreator` — игнорирование результата перевода

**Файл:** CalculatorCaller.sol:50

```solidity
payable(creator).call{value: msg.value}("");
```

Возврат не проверяется — если у автора reject-fallback или закончился газ, ETH останется на балансе CalculatorCaller без оповещения отправителя.

**Исправление:** `(bool ok, ) = payable(creator).call{value: msg.value}(""); require(ok, "transfer failed");`.

---

## 4. Отчёт по проверкам (тексты сообщений)

Многие `require` содержат неинформативные строки. Предлагаю осмысленные сообщения; в исправленной версии применены **custom errors** как более газоэффективный вариант.

| Строка | Было | Предлагаемый текст |
|---|---|---|
| 15 | `"can't find a version"` | `"CalculatorCaller: getVersion() call failed"` |
| 26 | `"zero address"` | `"fund: recipient is zero address"` |
| 28 | `"bad fund"` | `"fund: transfer to recipient failed"` |
| 32 | `"only owner"` | `"take: caller is not owner"` |
| 35 | `"bad call"` | `"take: withdraw to owner failed"` |
| 39 | `"zero address"` | `"support: calculator is zero address"` |
| 41 | `"____"` | `"support: getVersion() call failed"` |
| 44 | `"not found"` | `"support: calculator not registered"` |
| 47 | `""` | `"support: getCreator() call failed"` |
| 50 | (нет проверки) | `"support: payout to creator failed"` |
| 71 | `""` | `"addCalc: calculator is zero address"` |
| 73 | `"_ne_"` | `"addCalc: getVersion() call failed"` |
| 81 | `"you can't update old calculator"` | `"addCalc: version already registered"` |
| 91 | `"error, incorrect version"` (удаляется по п. 3.4) | — |
| 102 | `"error add call"` | `"callAdd: underlying call failed"` |
| 110 | `"-"` | `"callMinus: underlying call failed"` |
| 118 | `"error multiple call"` | `"callMultiple: underlying call failed"` |
| 125 | `"error division call"` | `"callDivision: underlying call failed"` |
| Calculator 55 | `"b is zero"` | `"division: divisor is zero"` |

---

## 5. Отчёт по информационной безопасности

### 5.1 `tx.origin` в авторизации (Critical)

`take()` использует `tx.origin` — классическая phishing-уязвимость. Любой контракт, которому владелец передаст транзакцию, сможет вывести весь баланс.

### 5.2 Отсутствие контроля доступа у `addNewCalculator` (High)

Любой пользователь может зарегистрировать произвольный адрес как «калькулятор». Дальнейшие `callAdd/callMinus/…` пойдут через `.call` на этот адрес — **произвольное исполнение кода** в контексте CalculatorCaller. Вредоносный «калькулятор» может:

- возвращать любые данные, имитируя арифметику, и воровать смысл результата у клиента;
- реентрить в CalculatorCaller (хотя прямой прибыли нет — ETH через `call*` не отправляется).

**Рекомендация:** модификатор `onlyOwner` либо отдельный allow-list.

### 5.3 `_getUserSelectedVersion` — неявный fallback на последнюю версию (Medium)

См. п. 3.1 — баг приводит к тому, что выбор пользователя игнорируется. С точки зрения ИБ это ещё и **нарушение контракта с пользователем**: он ожидает детерминированную версию, а получает ту, которую назначил кто-то другой через `addNewCalculator`.

### 5.4 `supportCalculatorCreator` — DoS через gas griefing и потеря средств (Medium)

Отсутствие `require` на возврат `.call` означает:

1. Если `creator` — контракт с потребляющим fallback-ом, `msg.value` может быть «съеден» газом, а отправитель подумает, что донат ушёл.
2. Если fallback revert-ит тихо, ETH остаётся на балансе CalculatorCaller и его заберёт `take()`.

### 5.5 `abi.decode` на неподконтрольных данных (Medium)

`firstCalculator.call("getVersion()")` с последующим `abi.decode` в `constructor`, `addNewCalculator`, `supportCalculatorCreator` — при возврате произвольных байтов `abi.decode` может ревертить; более опасно — ABI-путаница, если злоумышленник подаст контракт с совместимой по длине, но семантически другой структурой (например, подменит `mainVersion` на значение, обходящее проверку возрастания).

**Рекомендация:** проверять `data.length` перед `abi.decode` и использовать ERC-165 `supportsInterface`.

### 5.6 Отсутствие reentrancy-защиты на `callAdd/Minus/Multiple/Division` (Low)

Функции `non-payable` и не меняют storage до внешнего вызова, но в сочетании с 5.2 (произвольный адрес в реестре) reentry-сценарии с изменением `userSelectedVersion` в callback-е возможны. В текущем коде состояние после `call` не читается — эффекта нет, но это хрупкий инвариант.

**Рекомендация:** модификатор `nonReentrant` (OpenZeppelin).

### 5.7 Shadowing/visibility (Low)

- `calculators`, `userSelectedVersion`, `lastVersion`, `owner` — без модификатора видимости (дефолтный `internal`). Читаться снаружи не могут, хотя `getCalculator` предоставляет частичный доступ.
- `owner` неизменяем по смыслу — должен быть `immutable`.

### 5.8 Переполнение версии (Low)

Компоненты версии — `uint8` (max 255). При достижении 255 апгрейд больше невозможен. Для калькулятора не критично, но отмечу.

### 5.9 Отсутствие события у критических действий (Informational)

Нет событий у `changeSelectedVersion`, `take`, `fund`, `supportCalculatorCreator` — затрудняет off-chain аудит.

### 5.10 Коллизии версии-ключа (Informational)

Ключом в `calculators` служит строка `version`, формируемая самим добавляемым контрактом. Злоумышленник может развернуть контракт, возвращающий произвольную строку в `getVersion()` — например, ту, которую ещё не занял «официальный» Calculator, блокируя её навсегда.

**Рекомендация:** формировать ключ в самом CalculatorCaller из `(mainVersion, subVersion, tempVersion)` после валидации.

---

## 6. Оптимизация

1. **`immutable`:** `owner` в CalculatorCaller, `creator` в Calculator — задаются один раз в конструкторе.
2. **Custom errors вместо `require(..., string)`** — экономит деплой- и revert-газ (Solidity 0.8.4+).
3. **Кэширование storage:** `lastVersion.mainVersion/subVersion/tempVersion` читается трижды в `addNewCalculator` — копировать в memory.
4. **`calldata` для строк** там, где не требуется модификация (`_version` уже правильно; `version` в constructor — можно memory, OK).
5. **Удалить лишние касты:** `payable(msg.sender)` в Calculator — `creator` имеет тип `address`, кастом ничего не меняется.
6. **OpenZeppelin Strings:** заменить ручной `uintToString` на `Strings.toString` — меньше кода, протестировано.
7. **Комбинировать внешние вызовы** в `supportCalculatorCreator`: два `call` к одному адресу — можно ограничиться одним и кэшировать данные у калькулятора либо добавить метод `getVersionAndCreator()`.
8. **Видимость маппингов `public`** — авто-геттеры снимают необходимость в `getCalculator`.
9. **Индексировать параметры события:** `event newLatestVersion(address indexed calculator, string version);` — удобнее фильтровать.
10. **`unchecked`** в `uintToString` для `digits++`, `digits--`, `value /= 10` — переполнение невозможно.

Все эти правки применены в [fixed/CalculatorCaller.sol](fixed/CalculatorCaller.sol) и [fixed/Calculator.sol](fixed/Calculator.sol).

---

## 7. Тестирование

Тесты (Hardhat + ethers v6 + chai) в [test/CalculatorCaller.test.js](test/CalculatorCaller.test.js) покрывают функции `addNewCalculator()`, `changeSelectedVersion()`, `callDivision()`.

### Покрытие сценариев

**`addNewCalculator`:**
- Успешная регистрация новой версии выше текущей (major, minor, patch);
- Эмит события `newLatestVersion`;
- Ревёрт при нулевом адресе;
- Ревёрт при попытке повторной регистрации той же версии;
- Регистрация более старой версии **без** обновления `lastVersion` (после фикса 3.4);
- Ревёрт при вызове не-владельцем (после фикса 5.2);
- Ревёрт при регистрации контракта без `getVersion()`.

**`changeSelectedVersion`:**
- Выбор существующей версии — `currentAddress` совпадает с `getCalculator(_version)`;
- Выбор несуществующей — сброс, возврат последнего;
- Смена пользователем своего выбора, изоляция между пользователями;
- Связка с `callAdd/callDivision` — вызов идёт на выбранную версию.

**`callDivision`:**
- Деление ненулевых значений;
- Деление на ноль — revert внутреннего `require`, всплывает в `callDivision` с сообщением;
- Деление после `changeSelectedVersion` — используется выбранная реализация;
- Целочисленное усечение (7/2 == 3).

Запуск:

```bash
cd /root/Projects/audit
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox chai
npx hardhat test
```
