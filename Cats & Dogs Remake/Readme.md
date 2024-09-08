1. **Introduction** 

This  level-based  game  features movable  characters,  a  controllable environment,  and  two  types  of weapons. Players will use a keyboard, screen,  and  FPGA  board  (including switches,  push  buttons,  LEDs,  and seven-segment  displays)  to  navigate and interact with the game. 

2. **Input Control Explanation** 


![image](https://github.com/user-attachments/assets/b80a6c0a-fc4b-4d4a-9f10-e2cb4e61cec5)



Fig. 1 Switches & Push Buttons 

- Switches:  Control  game  level, wind speed, and weapon type. 
- Push  Buttons:  Control  attack, power adjustment, and game reset. 
- Keyboard:  Move  the  cat  and detonate the bomb.  
3. **Output Control Explanation** 

![image](https://github.com/user-attachments/assets/feecdc62-2cf3-4aad-811f-bd2c89fa44ab)



Fig. 2 LEDs Control (Win) 


![image](https://github.com/user-attachments/assets/3d587253-1d09-473d-a971-a2d6c535a85c)



Fig. 3 Seven-Segments Control 


![image](https://github.com/user-attachments/assets/9f4d8d93-6647-4f8a-9f4d-e89d900fbce1)



Fig. 4 the display of the game 

4. **The structure of the program** 


![image](https://github.com/user-attachments/assets/ce5a36fe-4f59-4608-b653-ee258a2cc3f5)



Fig. 5 Block Control Diagram 

In Fig. 5, the system control block diagram  is  categorized  into  three classes: Input/Output (green), Event Trigger  (orange),  and  Self-Control Objects  (blue).  It  clearly  illustrates the  signal  control  architecture  and interactions,  presenting  a  cohesive overall system design. 

5. **Reflection** 
- Learn  to  control  various  I/O devices on FPGA. 
- Design a system using a Mealy machine. 
