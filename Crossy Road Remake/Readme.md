### Key Takeaway
This project focuses on using a finite state machine to control the movement of an animal symbol on a VGA screen. The lab involves implementing Verilog codes to demonstrate various functionalities, including animal movement, correct motion of cars and trucks, accurate display of accumulated steps, boundary checking, successful crossing conditions, and failure indications.

### Summary
- **Lab Objective:** Implement a digital system using a finite state machine to control the movement of an animal symbol on a VGA screen.
- **Lab Components:** Verilog codes, FPGA board, push buttons (S4, S3, S0), seven-segment display, and LEDs.
- **Animal Control:**
  - S4: Move the animal upward.
  - S3: Move the animal to the left.
  - S0: Move the animal to the right.
- **Initial Setup:** Animals and vehicles move within defined lanes on the VGA screen.
- **Movement Rules:**
  - Limited to an 8x6 grid.
  - Release buttons to execute a single movement.
- **Scoring System:**
  - Accumulated steps displayed on a seven-segment display.
  - 99 points awarded for safely reaching the y=5 row without obstacles.
- **End Conditions:**
  - Successful End: Player wins 99 points when the animal safely crosses the road.
  - Failure End: LED blinks if the animal is hit by a vehicle or encounters a brick wall.
- **Visual Feedback:**
  - VGA screen updates to reflect movement and game state.
  - LED blinks in a specific pattern to indicate failure.
- **Lab Tasks:**
  1. Write Verilog codes for:
      - Animal movement with push buttons.
      - Correct motion of cars and trucks.
      - Accurate display of accumulated steps.
      - Boundary checking for push button movement.
      - Display of 99 points for successful crossing.
      - LED blinking in case of failure.
  2. Conduct a demo during the lab time.

*Note: The lab aims to simulate a game scenario on the FPGA board, testing the implementation of digital design concepts and verification of correct functionality.*
