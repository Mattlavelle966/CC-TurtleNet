local p,output = turtle.inspect()


local str = textutils.serialise(output)

print(output)
print(str)

file = fs.open("table", "w")
file.write(str)
file.close()

