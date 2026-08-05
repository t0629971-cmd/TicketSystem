local printer = peripheral.find("printer")

if not printer then
    print("Printer ne naiden!")
    return
end

if not printer.newPage() then
    print("Vstavte bumagu!")
    return
end

printer.setPageTitle("Bilet")

printer.setCursorPos(1,1)
printer.write("====================")

printer.setCursorPos(7,2)
printer.write("BILET")

printer.setCursorPos(1,3)
printer.write("====================")

printer.setCursorPos(1,5)
printer.write("Oplata: 2 almaza")

printer.setCursorPos(1,7)
printer.write("Status: OPLACHENO")

printer.setCursorPos(1,9)
printer.write("Spasibo za pokupku!")

printer.setCursorPos(1,11)
printer.write("Horoshei poezdki!")

printer.setCursorPos(1,13)
printer.write("====================")

printer.endPage()

print("Chek napechatan!")
