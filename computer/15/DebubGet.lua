local exist = fs.exists("BLOCK_DB.txt")
if (exist)then
    file = fs.open("BLOCK_DB.txt", "r")
    local content = file.readAll()
    pack = textutils.unserialize(content)

else
    print("it does not exists")
    file = fs.open("BLOCK_DB.txt", "w")
    pack = {coords={x=1,y=2,z=3}, time = os.date()}
    file.write(textutils.serialize(pack))
    file.close()
     
end