﻿
#Если Сервер Или ТолстыйКлиентОбычноеПриложение Тогда

#Область ОбработчикиСобытий

Процедура ПередЗаписью(Отказ, РежимЗаписи, РежимПроведения)
	
	Если ОбменДанными.Загрузка Тогда
		Возврат;
	КонецЕсли;
	
	СуммаПоДокументу = Товары.Итог("Стоимость");
	
КонецПроцедуры

Процедура ОбработкаПроведения(Отказ, РежимПроведения)
	
	СформироватьДвижения(Отказ);
	
КонецПроцедуры

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

Процедура СформироватьДвижения(Отказ)
	
	Движения.Остатки.Записать();
	Движения.Остатки.Записывать = Истина;
	
	Движения.Продажи.Записывать = Истина;
	
	РегистрыНакопления.Остатки.ЗаблокироватьИсключительноПоСкладуИТабличнойЧасти(Склад, Товары);
	
	МенеджерВТ = Новый МенеджерВременныхТаблиц;
	СоздатьВТТовары(МенеджерВТ);
	РегистрыНакопления.Остатки.СоздатьВТОстаткиПоТаблицеТоваров(МенеджерВТ, МоментВремени(), Склад);
	
	Запрос = Новый Запрос;
	Запрос.МенеджерВременныхТаблиц = МенеджерВТ;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	ВТ_Товары.Номенклатура КАК Номенклатура,
		|	ВТ_Товары.Номенклатура.Представление КАК НоменклатураПредставление,
		|	ЕСТЬNULL(ВТ_Остатки.Партия, ЗНАЧЕНИЕ(Документ.ПоступлениеТоваров.ПустаяСсылка)) КАК Партия,
		|	ВТ_Товары.Количество КАК Количество,
		|	ВТ_Товары.Продажа КАК Продажа,
		|	ЕСТЬNULL(ВТ_Остатки.КоличествоОстаток, 0) КАК КоличествоОстаток,
		|	ЕСТЬNULL(ВТ_Остатки.СтоимостьОстаток, 0) КАК СтоимостьОстаток
		|ИЗ
		|	ВТ_Товары КАК ВТ_Товары
		|		ЛЕВОЕ СОЕДИНЕНИЕ ВТ_Остатки КАК ВТ_Остатки
		|		ПО ВТ_Товары.Номенклатура = ВТ_Остатки.Номенклатура
		|
		|УПОРЯДОЧИТЬ ПО
		|	ВТ_Остатки.Партия.МоментВремени
		|ИТОГИ
		|	МАКСИМУМ(Количество),
		|	МАКСИМУМ(Продажа),
		|	СУММА(КоличествоОстаток),
		|	СУММА(СтоимостьОстаток)
		|ПО
		|	Номенклатура";
	
	МетодСписанияСебестоимости = РегистрыСведений.УчетнаяПолитика.МетодСписанияСебестоимости(Дата);
	
	Если МетодСписанияСебестоимости = Перечисления.МетодыСписанияСебестоимости.ЛИФО Тогда
		Запрос.Текст = СтрЗаменить(
			Запрос.Текст,
			"ВТ_Остатки.Партия.МоментВремени",
			"ВТ_Остатки.Партия.МоментВремени УБЫВ");
	КонецЕсли;
	
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаНоменклатура = РезультатЗапроса.Выбрать(ОбходРезультатаЗапроса.ПоГруппировкам);
	
	Пока ВыборкаНоменклатура.Следующий() Цикл
		
		Превышение = ВыборкаНоменклатура.Количество - ВыборкаНоменклатура.КоличествоОстаток;
		
		Если Превышение > 0 Тогда
			Сообщение = Новый СообщениеПользователю;
			Сообщение.Текст = СтрШаблон(
				НСтр("ru = 'Невозможно провести документ. По номенклатуре %1 превышение остатка на складе. Списание %2; Остаток %3; Превышение %4'"),
				ВыборкаНоменклатура.НоменклатураПредставление,
				ВыборкаНоменклатура.Количество, 
				ВыборкаНоменклатура.КоличествоОстаток,
				Превышение);
			Сообщение.Сообщить();
			Отказ = Истина;
		КонецЕсли;
		
		Если Отказ Тогда
			Продолжить;
		КонецЕсли;
		
		КоличествоСписать = ВыборкаНоменклатура.Количество;
		СтоимостьОбщая    = 0;
		
		ВыборкаДетальныеЗаписи = ВыборкаНоменклатура.Выбрать();
		
		Пока ВыборкаДетальныеЗаписи.Следующий()
			И КоличествоСписать > 0 Цикл
			
			Количество        = Мин(КоличествоСписать, ВыборкаДетальныеЗаписи.КоличествоОстаток);
			КоличествоСписать = КоличествоСписать - Количество;
			
			Если Количество = ВыборкаДетальныеЗаписи.КоличествоОстаток Тогда
				Стоимость = ВыборкаДетальныеЗаписи.СтоимостьОстаток;
			Иначе
				Стоимость = Количество / ВыборкаДетальныеЗаписи.КоличествоОстаток * ВыборкаДетальныеЗаписи.СтоимостьОстаток;
			КонецЕсли;
			
			Движение = Движения.Остатки.ДобавитьРасход();
			Движение.Период       = Дата;
			Движение.Склад        = Склад;
			Движение.Номенклатура = ВыборкаДетальныеЗаписи.Номенклатура;
			Движение.Партия       = ВыборкаДетальныеЗаписи.Партия;
			Движение.Количество   = Количество;
			Движение.Стоимость    = Стоимость;
			
			СтоимостьОбщая = СтоимостьОбщая + Стоимость;
			
		КонецЦикла;
		
		Движение = Движения.Продажи.Добавить();
		Движение.Период       = Дата;
		Движение.Номенклатура = ВыборкаНоменклатура.Номенклатура;
		Движение.Менеджер     = Менеджер;
		Движение.Количество   = ВыборкаНоменклатура.Количество;
		Движение.Стоимость    = СтоимостьОбщая;
		Движение.Продажа      = ВыборкаНоменклатура.Продажа;
		Движение.Цена         = ВыборкаНоменклатура.Продажа / ВыборкаНоменклатура.Количество;
		
	КонецЦикла;
	
КонецПроцедуры

Процедура СоздатьВТТовары(МенеджерВТ)
	
	Запрос = Новый Запрос;
	Запрос.МенеджерВременныхТаблиц = МенеджерВТ;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	РеализацияТоваровТовары.Номенклатура КАК Номенклатура,
		|	СУММА(РеализацияТоваровТовары.Количество) КАК Количество,
		|	СУММА(РеализацияТоваровТовары.Стоимость) КАК Продажа
		|ПОМЕСТИТЬ ВТ_Товары
		|ИЗ
		|	Документ.РеализацияТоваров.Товары КАК РеализацияТоваровТовары
		|ГДЕ
		|	РеализацияТоваровТовары.Ссылка = &Ссылка
		|
		|СГРУППИРОВАТЬ ПО
		|	РеализацияТоваровТовары.Номенклатура
		|
		|ИНДЕКСИРОВАТЬ ПО
		|	Номенклатура";
	
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	
	Запрос.Выполнить();

КонецПроцедуры

#КонецОбласти

#Иначе
ВызватьИсключение НСтр("ru = 'Недопустимый вызов объекта на клиенте.'");
#КонецЕсли
