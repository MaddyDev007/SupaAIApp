# SmartClass User Flow Guide

This guide explains how a user moves through the SmartClass app in the `smartclass` Flutter project. It is based on the current screen flow and navigation implemented in the app.

## 1. App Entry Flow

### Splash screen
- When the app opens, it shows a splash screen for about 3 seconds.
- If a Supabase session already exists, the app goes to `CommonDashboard`.
- If there is no session, the app goes to `OnboardingScreen`.

### Onboarding flow
- The onboarding has multiple intro slides.
- The user can:
  - Tap `Next` to move forward
  - Tap `Skip` to skip the intro
  - Tap `Get started` on the last page
- After onboarding, the app opens the Google sign-in page.

### Login flow
- The login screen uses `Continue with Google`.
- After successful authentication:
  - User data is stored in Supabase `users`
  - Basic profile is cached in Hive
  - The app navigates to `CommonDashboard`

## 2. Common Dashboard Flow

The `CommonDashboard` is the central class selection screen.

### Tabs available
- `Joined`: classes where the user is a student
- `Created`: classes created by the logged-in user
- `semester`: semester result lookup page

### Floating action button behavior
- On `Joined`, the `+` button opens `Join Class`
- On `Created`, the `+` button opens `Create Class`
- On `semester`, there is no floating action button

### Join class flow
1. Open the `Joined` tab.
2. Tap the `+` button.
3. Enter the class code.
4. Tap `Join`.
5. If valid, the class appears in the joined class list.

### Create class flow
1. Open the `Created` tab.
2. Tap the `+` button.
3. Enter the subject name.
4. Tap `Create`.
5. A class is created with a generated class code.
6. The teacher is automatically added as a member of the class.

### Open a class
- Tap any class card from `Joined` or `Created`.
- If the logged-in user is the class owner, the app opens `TeacherDashboard`.
- Otherwise, it opens `StudentDashboard`.

### Profile from common dashboard
- Tap the avatar in the top-right corner.
- This opens the main profile page (`ProfilePageNew`).
- From there the user can:
  - View name and email
  - Change theme mode: `System default`, `Light mode`, `Dark mode`
  - Logout

## 3. Semester Result Flow

The third tab in `CommonDashboard` opens `SemResultPage`.

### Fetch semester result
1. Open the `semester` tab.
2. Enter `Register Number`.
3. Enter `Date of Birth (DD-MM-YYYY)`.
4. Tap `Fetch Result`.
5. If successful, the app shows:
  - Register number
  - Name
  - Degree
  - Exam month
  - GPA
  - Subject-wise result list

### Additional actions in semester result
- Use the sort menu to sort by:
  - Semester
  - Grade
- Use the search icon to filter by course name or code
- Tap `Print` to print the result
- Tap `Download` to save the result PDF to the Downloads folder

## 4. Teacher Flow

When a teacher opens one of their created classes, `TeacherDashboard` appears.

### Teacher dashboard sections
The home screen shows cards for:
- `Upload Material`
- `Chatbot Assistant`
- `Quiz Results`
- `View Materials`
- `Question Banks`
- `Analytics Dashboard`

### Bottom navigation
- `Home`: shows all teacher feature cards
- `Materials`: shows `View Materials` and `Question Banks`
- `Quiz`: shows `Quiz Results`
- `Chat`: shows `Chatbot Assistant`
- `People`: opens the student list page

## 5. Teacher Upload File Flow

This is the main upload flow in the current project.

### How to navigate to upload file page
1. Open the app.
2. Sign in with Google.
3. Go to `CommonDashboard`.
4. Open the `Created` tab.
5. Tap your class card.
6. On `TeacherDashboard`, tap `Upload Material`.

### How to upload a file
1. On `Upload & Generate`, confirm the `Subject` field.
   - It is prefilled with the class name.
2. Tap `Pick PDF`.
3. Choose a PDF file from the device.
4. Confirm that the selected filename appears below the button.
5. Tap `Upload Material`.
6. Wait for the upload dialog and progress bar to complete.
7. After success, a snackbar confirms the material upload.

### Important upload rules
- Only PDF files are accepted in this page.
- The subject field must not be empty.
- The file must be selected before upload.
- The upload can be cancelled while progress is shown.

### After upload
Once a PDF is uploaded successfully, the teacher can continue with:

#### Generate quiz
1. Tap `Generate Quiz`.
2. The backend extracts the PDF text and creates quiz questions.
3. The quiz is stored for the class.
4. A success message appears after completion.

#### Generate exam / question bank
1. Tap `Generate Exam`.
2. The backend generates exam or question-bank style output.
3. A success message appears after completion.

## 6. Teacher Material Management Flow

### View uploaded materials
1. Open a teacher class.
2. Tap `View Materials`, or use bottom navigation `Materials`.
3. The page lists uploaded class materials created by that teacher.

### Actions available for each material
- Tap the card to open the PDF inside the app
- Tap external-open icon to open with another app
- Tap download icon to save to Downloads
- Tap delete icon to remove the material

### Delete material behavior
Deleting a material also removes:
- The file from storage
- Related question-bank files
- Related question records in the database

### Search materials
- Use the search field at the top
- Search works by subject name

## 7. Teacher Question Bank Flow

### Open question banks
1. Open a teacher class.
2. Tap `Question Banks`, or use bottom navigation `Materials`.

### Actions available
- Tap a card to open the PDF inside the app
- Open externally
- Download to Downloads
- Delete the question bank file

### Search question banks
- Use the search field to filter by subject

## 8. Teacher Quiz Results Flow

### Open quiz results
1. Open a teacher class.
2. Tap `Quiz Results`, or use bottom navigation `Quiz`.

### What the teacher can do
- Search results by student name
- Sort by:
  - Default
  - High to Low
  - Low to High
- Pull to refresh

### What is shown
- Student avatar
- Student name
- Subject
- Score

## 9. Teacher People / Student List Flow

### Open student list
1. Open a teacher class.
2. Tap bottom navigation `People`.

### Features on student list page
- Search students by name
- See total student count
- Tap a student row to open performance details
- Open the row menu to:
  - View performance
  - Remove from class

### Remove student behavior
Removing a student also deletes that student's:
- Results in that class
- Notes in that class
- Stored note images for that class
- Class membership

## 10. Teacher Analytics Flow

### Open analytics
1. Open a teacher class.
2. Tap `Analytics Dashboard`.

### What is shown
- Total students
- Number of quizzes taken
- Average score
- Student performance bar chart
- Detailed results table

## 11. Teacher Class Info / Delete Classroom Flow

### Open class profile/info
1. Open a teacher class.
2. Tap the top-right info icon.

### What is shown
- Teacher profile summary
- Class name
- Class code
- Role as teacher

### Delete classroom
1. Open class profile/info.
2. Tap `Delete Classroom`.
3. Confirm deletion.
4. The app calls the backend delete API.

### Delete classroom impact
This permanently deletes:
- Lesson materials
- Quizzes and question files
- Student notes in that class
- Results
- Student memberships in that class

## 12. Student Flow

When a student opens a joined class, `StudentDashboard` appears.

### Student dashboard sections
- `Start Quiz`
- `Ask Chatbot`
- `View Materials`
- `Question Banks`
- `Notes`
- `Analytics`

### Bottom navigation
- `Home`: all student feature cards
- `Materials`: shows `View Materials` and `Question Banks`
- `Quiz`: shows `Start Quiz`
- `Chat`: shows `Ask Chatbot`

## 13. Student Materials Flow

### View class materials
1. Open a joined class.
2. Tap `View Materials`, or use bottom navigation `Materials`.

### Actions available
- Tap a material card to open PDF in-app
- Open externally
- Download to Downloads
- Search by subject name
- Pull to refresh

## 14. Student Question Bank Flow

### View question banks
1. Open a joined class.
2. Tap `Question Banks`, or use bottom navigation `Materials`.

### Actions available
- Tap a card to open the PDF in-app
- Open externally
- Download to Downloads
- Search by subject
- Pull to refresh

## 15. Student Quiz Flow

### Start a quiz
1. Open a joined class.
2. Tap `Start Quiz`, or use bottom navigation `Quiz`.
3. The app shows all quizzes for that class.

### Quiz list behavior
- `All`: shows every quiz
- `Finished`: shows quizzes already attempted
- `Unfinished`: shows quizzes not yet attempted

### Take a quiz
1. Tap an unfinished quiz card.
2. The app verifies that the user is still a member of the class.
3. The quiz page opens with:
  - 150-second timer
  - One question at a time
  - Previous and Next buttons
  - Submit button on the final question
4. After submission:
  - Score is saved in Supabase
  - Completion dialog shows the final score

### Quiz restrictions
- Finished quizzes are disabled from retaking in the current flow
- A user removed from the class cannot continue into the quiz

## 16. Student Notes Flow

### Open notes
1. Open a joined class.
2. Tap `Notes`.

### Create a note
1. Tap the floating `+` button.
2. Choose a note color.
3. Optionally tap `Pick Image` to upload an image from gallery.
4. Enter `Title`.
5. Enter `Note`.
6. Tap `Save`.

### View a note
- Tap a note card
- Or tap the eye icon on the note card

### Edit a note
- Open the note
- Tap `Edit`
- Or tap the edit icon from the note list

### Delete a note
- Open the note and tap `Delete`
- Or tap the delete icon from the note list
- Deleting also removes the stored image if one exists

## 17. Student Analytics Flow

### Open student analytics
1. Open a joined class.
2. Tap `Analytics`.

### What is shown
- High score
- Average score
- Low score
- Score bar chart
- Detailed results table with subject and date

## 18. Chatbot Flow

The chatbot is available to both teacher and student inside a class.

### Open chatbot
- Teacher: tap `Chatbot Assistant` or bottom navigation `Chat`
- Student: tap `Ask Chatbot` or bottom navigation `Chat`

### Use chatbot
1. Enter a message in the text box.
2. Tap send.
3. The response streams live from the backend.
4. Use the stop button while streaming if needed.

### Chatbot actions
- Scroll through conversation history
- Tap the floating down button to jump to latest response
- Tap the delete icon in the app bar to clear chat history

## 19. Profile and Logout Flow

### Main profile page
Accessible from the avatar in `CommonDashboard`.

### Class profile page
Accessible from the info icon inside teacher/student dashboards.

### Logout
- Available from the main profile page
- On logout, the app:
  - Signs out from Supabase
  - Clears Hive cached profile
  - Clears chatbot history
  - Navigates back to login

## 20. Current Behavior Notes

These are important implementation details from the current code:

- Profile editing exists in older commented code, but it is not currently exposed in active UI flow.
- File upload currently supports PDF only.
- Teacher material list shows only materials uploaded by the logged-in teacher for that class.
- Student materials and question banks are class-based and available to all members of that class.
- Semester result lookup is separate from class-based learning flow.
- Many list pages support pull-to-refresh and search.

## 21. Quick Navigation Summary

### Teacher shortest path to upload file
`Login -> CommonDashboard -> Created tab -> Select class -> Upload Material -> Pick PDF -> Upload Material`

### Teacher shortest path to see students
`Login -> CommonDashboard -> Created tab -> Select class -> People`

### Student shortest path to take quiz
`Login -> CommonDashboard -> Joined tab -> Select class -> Start Quiz`

### Student shortest path to make notes
`Login -> CommonDashboard -> Joined tab -> Select class -> Notes -> +`
