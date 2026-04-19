// Проверки аудита — иллюстрация того, что было протестировано.
// Запуск не предполагается: окружение (geth, компиляция через solc, фабрики
// контрактов) удалено. Здесь оставлены только сами проверки и их смысл.

const { ethers } = require("ethers");
const assert = require("node:assert/strict");

// v1 с версией 1.0.0 передаётся в конструктор CalculatorCaller
const v1 = await CalcF.deploy(1, 0, 0);
const caller = await CallerF.deploy(await v1.getAddress());


// ────── Ф1: addNewCalculator — регистрация новой версии калькулятора ──────

// новая версия регистрируется и становится последней
const v2 = await CalcF.deploy(2, 0, 0);
await caller.addNewCalculator(await v2.getAddress());
assert.equal(await caller.getCalculator("2.0.0"), await v2.getAddress());
assert.equal((await caller.getLastVersion()).version, "2.0.0");

// нулевой адрес отклоняется
await assert.rejects(caller.addNewCalculator(ethers.ZeroAddress));

// повторная регистрация версии с тем же номером отклоняется
const dup = await CalcF.deploy(1, 0, 0);
await assert.rejects(caller.addNewCalculator(await dup.getAddress()));


// ────── Ф2: changeSelectedVersion — выбор пользователем активной версии ──────

// существующая версия сохраняется за пользователем
await caller.changeSelectedVersion("1.0.0");
assert.equal(await caller.getUserVersion(ownerAddr), "1.0.0");

// несуществующая версия сбрасывает выбор пользователя в пустую строку
await caller.changeSelectedVersion("9.9.9");
assert.equal(await caller.getUserVersion(ownerAddr), "");

// функция возвращает адрес контракта выбранной версии
const ret = await caller.changeSelectedVersion.staticCall("2.0.0");
assert.equal(ret, await v2.getAddress());


// ────── Ф3: callDivision — делегирование деления выбранному калькулятору ──────

// целочисленное деление
assert.equal(await caller.callDivision.staticCall(10, 2), 5n);
assert.equal(await caller.callDivision.staticCall(7, 2), 3n);

// деление на ноль отклоняется
await assert.rejects(caller.callDivision.staticCall(1, 0));
