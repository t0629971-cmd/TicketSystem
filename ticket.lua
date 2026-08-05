local printer = peripheral.find("printer")

if not printer then
    print("Printer not found!")
    return
end

if not printer.newPage() then
    print("Insert paper into the printer!")
    return
end

printer.setPageTitle("Ticket")

printer.setCursorPos(1,1)
printer.write("===================")

printer.setCursorPos(1,2)
printer.write("      TICKET")

printer.setCursorPos(1,3)
printer.write("===================")

printer.setCursorPos(1,5)
printer.write("Payment: 2 Diamonds")

printer.setCursorPos(1,7)
printer.write("Status: PAID")

printer.setCursorPos(1,9)
printer.write("Enjoy your trip!")

printer.endPage()

print("Ticket printed!")
