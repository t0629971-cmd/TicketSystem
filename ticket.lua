local printer = peripheral.find("printer")

if not printer then
    print("Принтер не найден!")
    return
end

if not printer.newPage() then
    print("Вставьте бумагу!")
    return
end

printer.setPageTitle("Билет")

printer.setCursorPos(1,1)
printer.write("====================")

printer.setCursorPos(4,2)
printer.write("БИЛЕТ")

printer.setCursorPos(1,3)
printer.write("====================")

printer.setCursorPos(1,5)
printer.write("Оплата:")
printer.setCursorPos(10,5)
printer.write("2 алмаза")

printer.setCursorPos(1,7)
printer.write("Статус:")
printer.setCursorPos(10,7)
printer.write("ОПЛАЧЕНО")

printer.setCursorPos(1,9)
printer.write("Спасибо за покупку!")

printer.setCursorPos(1,11)
printer.write("Хорошей поездки!")

printer.setCursorPos(1,13)
printer.write("====================")

printer.endPage()

print("Чек напечатан!")
