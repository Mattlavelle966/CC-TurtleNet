# MineNet-CC

MineNet-CC is a distributed networking framework built for [ComputerCraft / CC: Tweaked](https://tweaked.cc/) inside Minecraft.  
It provides a way to simulate real-world networking concepts like client–server communication, autonomous nodes, persistent data storage, and modular UI design — all within the sandbox environment of CC: Tweaked.

---

##  Features

- **Client–Server Networking**  
  A master server (`MasterServer.lua`) coordinates and manages nodes across the network.

- **Autonomous Nodes**  
  Each node (`NodeMind.lua`) is capable of independent behavior while maintaining communication with the server.

- **Custom UI Framework**  
  Includes reusable UI components (`ui_lib.lua`, `mine_net_ui.lua`) for building interactive interfaces.

- **Scalability**  
  Built to handle unlimited number of nodes without code changes.

- **Persistence**  
  Custom database logic enables saving and retrieving state between sessions.

---

##  Project Structure

```
Node*/
├── mine_net.lua         # Core networking library
├── NodeMind.lua         # Autonomous node logic - would be called startup.lua
├── TMNL.lua             # Terminal/node interaction logic

MasterServer/
├── MaserServer.lua      # Core server logic - would be called startup.lua
├── mine_net.lua         # Core networking library
├── mine_net_ui.lua      # Networking UI components
├── ui_lib.lua           # General-purpose UI library

MineNetUI/
├── MasterMineUI.lua     # Master server user interface - would be called startup.lua
├── mine_net.lua         # Core networking library
├── ui_lib.lua           # General-purpose UI library
```

---

##  Requirements

- Minecraft with [CC: Tweaked](https://tweaked.cc/)  
- At least one ComputerCraft computer or turtle for the server  
- Additional computers/turtles for connecting nodes  

---

##  Usage

1. Copy the contents of the `Work/` directory into your ComputerCraft computer(s).  
2. On the **server computer**, run:  
   ```
   MaserServer.lua   * rename to startup.lua 
   mine_net.lua         
   mine_net_ui.lua      
   ui_lib.lua 
   ```
3. On each **node computer**, run:  
   ```lua
   mine_net.lua         
   NodeMind.lua      * rename to startup.lua         
   TMNL.lua 
   ```
4. To launch the **UI interface**, use:  
   ```lua
   MasterMineUI.lua  * rename to startup.lua   
   mine_net.lua         
   ui_lib.lua 
   ```

##  Media

You can embed screenshots, gifs, or videos here to show setup and demos. Example:

![MineNet UI Screenshot](https://drive.google.com/uc?export=view&id=1KqF3ZjjfUeHFwHxlp8484CImFAK6jeFS)

For videos or GIFs, upload them to a host (e.g., GitHub repo, Imgur, or YouTube) and embed:

[![MineNet Demo](https://drive.google.com/uc?export=view&id=1KqF3ZjjfUeHFwHxlp8484CImFAK6jeFS)]

---

##  Contributing

Contributions, bug reports, and feature suggestions are welcome.  
If you’d like to contribute, please fork the repo and submit a pull request with clear documentation.
