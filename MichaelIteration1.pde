import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 150; //you will need to look up the DPI or PPI of your device to make sure you get the right scale!!
//http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density

//Do not change the following variables
String[] phrases; //contains all of the phrases
String[] suggestions; //contains all of the phrases
int totalTrialNum = 3 + (int)random(3); //the total number of phrases to be tested - set this low for testing. Might be ~10 for the real bakeoff!
int currTrialNum = 0; // the current trial number (indexes into trials array above)
float startTime = 0; // time starts when the first letter is entered
float finishTime = 0; // records the time of when the final trial ends
float lastTime = 0; //the timestamp of when the last trial was completed
float lettersEnteredTotal = 0; //a running total of the number of letters the user has entered (need this for final WPM computation)
float lettersExpectedTotal = 0; //a running total of the number of letters expected (correct phrases)
float errorsTotal = 0; //a running total of the number of errors (when hitting next)
String currentPhrase = ""; //the current target phrase
String currentTyped = ""; //what the user has typed so far
final float sizeOfInputArea = DPIofYourDeviceScreen*1; //aka, 1.0 inches square!
PImage watch;
PImage mouseCursor;
float cursorHeight;
float cursorWidth;

// Variables for phone keypad implementation
String[][] keypadLetters = {
  {"a", "b", "c"}, 
  {"d", "e", "f"}, 
  {"g", "h", "i"},
  {"j", "k", "l"}, 
  {"m", "n", "o"}, 
  {"p", "q", "r"},
  {"s", "t", "u"}, 
  {"v", "w", "x"}, 
  {"y", "z", ""}
};
float buttonWidth, buttonHeight;
int lastButtonPressed = -1; // Track which button was last pressed
int currentLetterIndex = 0; // Index of the current letter in the button
long lastClickTime = 0; // When the last click happened
final long CLICK_TIMEOUT = 1000; // Time window for multi-clicks in ms
String previewLetter = ""; // Letter currently being cycled through
int nextLetterButton = -1; // Button that contains the next letter of the target phrase
float textSizeSmall, textSizeMedium, textSizeLarge; // Scaled text sizes

//You can modify anything in here. This is just a basic implementation.
void setup()
{
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt"); //load the phrase set into memory 
  Collections.shuffle(Arrays.asList(phrases), new Random()); //randomize the order of the phrases with no seed
  //Collections.shuffle(Arrays.asList(phrases), new Random(100)); //randomize the order of the phrases with seed 100; same order every time, useful for testing
 
  orientation(LANDSCAPE); //can also be PORTRAIT - sets orientation on android device
  size(800, 800); //Sets the size of the app. You should modify this to your device's native size. Many phones today are 1080 wide by 1920 tall.
  
  // Calculate scaled text sizes based on DPI
  float scaleFactor = DPIofYourDeviceScreen / 250.0; // Base scaling factor
  textSizeSmall = 16 * scaleFactor;
  textSizeMedium = 24 * scaleFactor;
  textSizeLarge = 32 * scaleFactor;
  
  textFont(createFont("Arial", textSizeMedium)); //set the font to arial with scaled size
  noStroke(); //my code doesn't use any strokes
  
  //set finger as cursor. do not change the sizing.
  noCursor();
  mouseCursor = loadImage("finger.png"); //load finger image to use as cursor
  cursorHeight = DPIofYourDeviceScreen * (400.0/250.0); //scale finger cursor proportionally with DPI
  cursorWidth = cursorHeight * 0.6; 
  
  // Calculate button dimensions - keeping them proportional to the input area
  buttonWidth = sizeOfInputArea / 3;
  buttonHeight = sizeOfInputArea / 4;
}

//You can modify anything in here. This is just a basic implementation.
void draw()
{
  background(255); //clear background
  drawWatch(); //draw watch background
  fill(100);
  rect(width/2-sizeOfInputArea/2, height/2-sizeOfInputArea/2, sizeOfInputArea, sizeOfInputArea); //input area should be 1" by 1"

  if (finishTime!=0)
  {
    fill(128);
    textAlign(CENTER);
    textSize(textSizeMedium);
    text("Finished", width/2, height/4); // Centered on screen
    cursor(ARROW);
    return;
  }

  if (startTime==0 & !mousePressed)
  {
    fill(128);
    textAlign(CENTER);
    textSize(textSizeMedium);
    text("Click to start time!", width/2, height/4); // Centered on screen
  }

  if (startTime==0 & mousePressed)
  {
    nextTrial(); //start the trials!
  }

  if (startTime!=0)
  {
    // Scale positions based on DPI and screen size
    float infoX = width * 0.1; // Left 10% of screen
    float infoY = height * 0.1; // Top 10% of screen
    float lineSpacing = textSizeMedium * 1.5; // Space between lines
    
    //feel free to change the size and position of the target/entered phrases and next button 
    textAlign(LEFT); //align the text left
    textSize(textSizeMedium);
    fill(128);
    text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, infoX, infoY); //draw the trial count
    fill(128);
    text("Target:   " + currentPhrase, infoX, infoY + lineSpacing); //draw the target string
    
    // Display current typed text with preview of currently selected letter
    if (previewLetter.length() > 0 && (millis() - lastClickTime) < CLICK_TIMEOUT) {
      fill(255, 0, 0); // Red for the preview letter
      text("Entered:  " + currentTyped + previewLetter + "|", infoX, infoY + lineSpacing * 2);
    } else {
      text("Entered:  " + currentTyped + "|", infoX, infoY + lineSpacing * 2);
      
      // If we've timed out, commit the preview letter
      if (previewLetter.length() > 0 && (millis() - lastClickTime) >= CLICK_TIMEOUT) {
        currentTyped += previewLetter;
        previewLetter = "";
        lastButtonPressed = -1;
      }
    }

    // Find which button contains the next letter needed
    findNextLetterButton();
    
    // Draw the 9-button phone keypad
    drawPhoneKeypad();
    
    // Draw next button at scaled position
    float nextButtonSize = sizeOfInputArea * 0.25; // 1/4 of input area size
    float nextX = width * 0.75;
    float nextY = height * 0.75;
    
    fill(255, 0, 0);
    rect(nextX, nextY, nextButtonSize, nextButtonSize); //draw next button
    fill(255);
    textAlign(CENTER, CENTER);
    text("NEXT >", nextX + nextButtonSize/2, nextY + nextButtonSize/2); //draw next label
  }
  
  //draw cursor with middle of the finger nail being the cursor point. do not change this.
  image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3, mouseY+cursorHeight/2-cursorHeight/5, cursorWidth, cursorHeight); //draw user cursor   
}

// Helper method to find which button contains the next letter needed
void findNextLetterButton() {
  nextLetterButton = -1;
  
  if (currentPhrase.length() <= currentTyped.length()) {
    return; // We've typed the full phrase already
  }
  
  // Get the next character needed
  char nextChar = currentPhrase.charAt(currentTyped.length());
  
  // Convert to lowercase for comparison
  nextChar = Character.toLowerCase(nextChar);
  
  // Find which button contains this letter
  for (int i = 0; i < keypadLetters.length; i++) {
    for (int j = 0; j < keypadLetters[i].length; j++) {
      if (keypadLetters[i][j].length() > 0 && keypadLetters[i][j].charAt(0) == nextChar) {
        nextLetterButton = i;
        return;
      }
    }
  }
  
  // If it's a space, set to the space button (bottom row, first button)
  if (nextChar == ' ') {
    nextLetterButton = 9; // Special value for space button
  }
}

void drawPhoneKeypad() {
  textAlign(CENTER, CENTER);
  
  // Draw the 9 letter buttons (3x3 grid)
  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 3; col++) {
      int index = row * 3 + col;
      float x = width/2 - sizeOfInputArea/2 + col * buttonWidth;
      float y = height/2 - sizeOfInputArea/2 + row * buttonHeight;
      
      // Determine button color based on different states
      if (index == lastButtonPressed && (millis() - lastClickTime) < CLICK_TIMEOUT) {
        // Currently active button (being clicked)
        fill(200, 200, 0); // Bright yellow highlight
      } else if (index == nextLetterButton) {
        // Button containing the next letter needed
        fill(0, 200, 200); // Cyan highlight for next letter
      } else {
        // Normal button
        fill(200); // Regular grey button
      }
      
      rect(x, y, buttonWidth, buttonHeight);
      
      // Show the letters on this button
      fill(0);
      textSize(textSizeSmall);
      String buttonText = "";
      for (int i = 0; i < keypadLetters[index].length; i++) {
        if (!keypadLetters[index][i].equals("")) {
          if (i > 0) buttonText += " ";
          buttonText += keypadLetters[index][i];
        }
      }
      text(buttonText, x + buttonWidth/2, y + buttonHeight/2 - textSizeSmall/2);
      
      // If this button was just pressed, highlight the currently selected letter
      if (index == lastButtonPressed && (millis() - lastClickTime) < CLICK_TIMEOUT) {
        fill(255, 0, 0); // Red for selected letter
        textSize(textSizeLarge); // Make the selected letter larger
        text(keypadLetters[index][currentLetterIndex], x + buttonWidth/2, y + buttonHeight/2 + textSizeMedium/2);
        textSize(textSizeMedium); // Reset text size
      }
    }
  }
  
  // Draw the final row (space, submit, backspace)
  String[] bottomRowLabels = {"SPACE", "SUBMIT", "BACK"};
  for (int i = 0; i < 3; i++) {
    float x = width/2 - sizeOfInputArea/2 + i * buttonWidth;
    float y = height/2 - sizeOfInputArea/2 + 3 * buttonHeight;
    
    // Special coloring for space if it's the next needed character
    if (i == 0) {
      if (nextLetterButton == 9) { // 9 is our special value for space button
        fill(0, 200, 200); // Cyan highlight for next needed character
      } else {
        fill(150, 150, 255); // Normal space button color
      }
    }
    else if (i == 1) fill(0, 255, 0); // Submit button
    else fill(255, 0, 0); // Back button
    
    rect(x, y, buttonWidth, buttonHeight);
    fill(0);
    textSize(textSizeSmall * 0.9); // Slightly smaller text for these buttons to fit
    text(bottomRowLabels[i], x + buttonWidth/2, y + buttonHeight/2);
    textSize(textSizeMedium); // Reset text size
  }
}

boolean didMouseClick(float x, float y, float w, float h) //simple function to do hit testing
{
  return (mouseX > x && mouseX<x+w && mouseY>y && mouseY<y+h); //check to see if it is in button bounds
}

void mousePressed()
{
  // First check if we need to handle the external next button
  float nextButtonSize = sizeOfInputArea * 0.25;
  float nextX = width * 0.75;
  float nextY = height * 0.75;
  
  if (didMouseClick(nextX, nextY, nextButtonSize, nextButtonSize)) {
    // Commit any pending letter first
    if (previewLetter.length() > 0) {
      currentTyped += previewLetter;
      previewLetter = "";
    }
    nextTrial();
    return;
  }
  
  // Check if the click is within the input area
  if (mouseX > width/2 - sizeOfInputArea/2 && 
      mouseX < width/2 + sizeOfInputArea/2 && 
      mouseY > height/2 - sizeOfInputArea/2 && 
      mouseY < height/2 + sizeOfInputArea/2) {
    
    // Calculate which button was pressed
    int col = int((mouseX - (width/2 - sizeOfInputArea/2)) / buttonWidth);
    int row = int((mouseY - (height/2 - sizeOfInputArea/2)) / buttonHeight);
    
    // Constrain to valid range
    col = constrain(col, 0, 2);
    row = constrain(row, 0, 3);
    
    if (row < 3) { // Letter buttons (0-8)
      int buttonIndex = row * 3 + col;
      
      // Check if this is a repeat press of the same button
      if (buttonIndex == lastButtonPressed && (millis() - lastClickTime) < CLICK_TIMEOUT) {
        // Cycle to the next letter on this button
        currentLetterIndex = (currentLetterIndex + 1) % keypadLetters[buttonIndex].length;
        // Skip empty strings (for the "yz" button which has no third letter)
        if (keypadLetters[buttonIndex][currentLetterIndex].equals("")) {
          currentLetterIndex = 0;
        }
      } else {
        // First press of this button - commit any pending letter
        if (previewLetter.length() > 0) {
          currentTyped += previewLetter;
        }
        
        // Start with first letter of new button
        lastButtonPressed = buttonIndex;
        currentLetterIndex = 0;
      }
      
      // Update the preview letter and time
      previewLetter = keypadLetters[buttonIndex][currentLetterIndex];
      lastClickTime = millis();
      
    } else { // Bottom row special buttons
      // First, commit any pending letter
      if (previewLetter.length() > 0) {
        currentTyped += previewLetter;
        previewLetter = "";
      }
      
      if (col == 0) { // Space
        currentTyped += " ";
      } else if (col == 1) { // Submit
        nextTrial();
      } else if (col == 2) { // Back/Delete
        if (currentTyped.length() > 0) {
          currentTyped = currentTyped.substring(0, currentTyped.length()-1);
        }
      }
      
      // Reset button state
      lastButtonPressed = -1;
    }
  }
}

void mouseReleased() {
  // We're no longer using the press-and-hold approach, so we don't need to do anything on release
}

void nextTrial()
{
  if (currTrialNum >= totalTrialNum) //check to see if experiment is done
    return; //if so, just return

  if (startTime!=0 && finishTime==0) //in the middle of trials
  {
    System.out.println("==================");
    System.out.println("Phrase " + (currTrialNum+1) + " of " + totalTrialNum); //output
    System.out.println("Target phrase: " + currentPhrase); //output
    System.out.println("Phrase length: " + currentPhrase.length()); //output
    System.out.println("User typed: " + currentTyped); //output
    System.out.println("User typed length: " + currentTyped.length()); //output
    System.out.println("Number of errors: " + computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim())); //trim whitespace and compute errors
    System.out.println("Time taken on this trial: " + (millis()-lastTime)); //output
    System.out.println("Time taken since beginning: " + (millis()-startTime)); //output
    System.out.println("==================");
    lettersExpectedTotal+=currentPhrase.trim().length();
    lettersEnteredTotal+=currentTyped.trim().length();
    errorsTotal+=computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim());
  }

  //probably shouldn't need to modify any of this output / penalty code.
  if (currTrialNum == totalTrialNum-1) //check to see if experiment just finished
  {
    finishTime = millis();
    System.out.println("==================");
    System.out.println("Trials complete!"); //output
    System.out.println("Total time taken: " + (finishTime - startTime)); //output
    System.out.println("Total letters entered: " + lettersEnteredTotal); //output
    System.out.println("Total letters expected: " + lettersExpectedTotal); //output
    System.out.println("Total errors entered: " + errorsTotal); //output

    float wpm = (lettersEnteredTotal/5.0f)/((finishTime - startTime)/60000f); //FYI - 60K is number of milliseconds in minute
    float freebieErrors = lettersExpectedTotal*.05; //no penalty if errors are under 5% of chars
    float penalty = max(errorsTotal-freebieErrors, 0) * .5f;
    
    System.out.println("Raw WPM: " + wpm); //output
    System.out.println("Freebie errors: " + freebieErrors); //output
    System.out.println("Penalty: " + penalty);
    System.out.println("WPM w/ penalty: " + (wpm-penalty)); //yes, minus, becuase higher WPM is better
    System.out.println("==================");

    currTrialNum++; //increment by one so this mesage only appears once when all trials are done
    return;
  }

  if (startTime==0) //first trial starting now
  {
    System.out.println("Trials beginning! Starting timer..."); //output we're done
    startTime = millis(); //start the timer!
  } 
  else
    currTrialNum++; //increment trial number

  lastTime = millis(); //record the time of when this trial ended
  currentTyped = ""; //clear what is currently typed preparing for next trial
  currentPhrase = phrases[currTrialNum]; // load the next phrase!
  //currentPhrase = "abc"; // uncomment this to override the test phrase (useful for debugging)
}


void drawWatch()
{
  float watchscale = DPIofYourDeviceScreen/138.0;
  pushMatrix();
  translate(width/2, height/2);
  scale(watchscale);
  imageMode(CENTER);
  image(watch, 0, 0);
  popMatrix();
}

//=========SHOULD NOT NEED TO TOUCH THIS METHOD AT ALL!==============
int computeLevenshteinDistance(String phrase1, String phrase2) //this computers error between two strings
{
  int[][] distance = new int[phrase1.length() + 1][phrase2.length() + 1];

  for (int i = 0; i <= phrase1.length(); i++)
    distance[i][0] = i;
  for (int j = 1; j <= phrase2.length(); j++)
    distance[0][j] = j;

  for (int i = 1; i <= phrase1.length(); i++)
    for (int j = 1; j <= phrase2.length(); j++)
      distance[i][j] = min(min(distance[i - 1][j] + 1, distance[i][j - 1] + 1), distance[i - 1][j - 1] + ((phrase1.charAt(i - 1) == phrase2.charAt(j - 1)) ? 0 : 1));

  return distance[phrase1.length()][phrase2.length()];
}
