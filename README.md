
                                                                 TEILEN 


Objective:

   The primary objective of this project is to develop a mobile application that enables individuals and groups to manage their debt relationships in a more organized, secure, and user-friendly manner within a digital environment. It aims to eliminate confusion commonly encountered in daily borrowing and lending situations by allowing users to record their transactions and track them through a single platform.

   The Teilen application is developed using the Flutter framework and is compatible with both Android and iOS platforms. While Firebase is used to manage user registrations, debt data, group information, and the notification system, financial transactions are recorded using a PHP API and MySQL database. This structure allows users to load balance into the system, make payments, and view their transaction history.

   In addition to debt creation and payment functionalities, the application also includes features such as group management, friend request system, messaging, and customizable notification settings, offering users a fully integrated financial control tool. User balances are tracked on two levels: an active in-app balance (balance) and a main balance (main_balance) operating under banking logic. This distinction allows for safer and more transparent financial management and debt closure.

   The purpose of this study is not only to develop a functioning application, but also to design a multi-layered and sustainable system by integrating different technologies such as Flutter, Firebase, PHP, and MySQL. The project not only addresses everyday user needs through its technical infrastructure but also provides a valuable learning experience for the developer in terms of system architecture and technological integration.



-------------------------------------------------------------------------------------------------

   The general system structure of the Teilen application is visually represented by the architectural diagram provided in this Figure:

![image](https://github.com/user-attachments/assets/e9229716-af1e-4568-be8b-b0608be40af3)

-------------------------------------------------------------------------------------------------

   These data are presented within the Flutter application through a user-friendly interface and are categorized individually. In Figure 4.2, the interface view shows the user’s actions such as withdrawing money, depositing funds, paying debts, and receiving payments from other users. This screen provides a transparent experience by displaying transaction details that exactly match the rows recorded in the database.

![image](https://github.com/user-attachments/assets/1e772a84-233b-423e-b5e3-a55aae1a5cc7)

-------------------------------------------------------------------------------------------------

   In addition, the application uses real-time notifications to inform the other party after actions such as adding an individual debt or requesting a group debt. Figure 4.3 shows individual and group debt notifications received by the user, as well as notifications indicating that the other party has paid their debt. These notifications are stored in the notifications collection in Firestore and are instantly reflected in the Flutter application.

![image](https://github.com/user-attachments/assets/b940175b-8b45-422c-bd34-7fd666ef7405)

-------------------------------------------------------------------------------------------------

   After a debt notification is received, the relevant transaction details can be viewed on the individual debt screen, as shown in Figure 4.4. Through this screen, the user can verify to whom the debt was given or from whom it was received, the amount, the description, and the creation date of the debt. In this way, debt-related actions are presented in a clear and user-friendly interface.

![image](https://github.com/user-attachments/assets/60f1bead-b240-4ff5-a502-15699875133f)

-------------------------------------------------------------------------------------------------

   For group debts, users can create a group within the application, specify a total amount, and automatically distribute this amount among the members. Figure 4.5 shows the group debt creation screen and a visual of the created group debt card. Unlike individual transactions, the group debt system informs multiple users simultaneously and operates synchronously with the Firebase Notification system.

![image](https://github.com/user-attachments/assets/68c115da-a537-41ae-9535-7a8fb28ca585)

-------------------------------------------------------------------------------------------------

   Once the group debt creation process is completed in the application, each user's individual debt status within the group can be tracked in detail. This feature is provided through the group detail screen shown in Figure 4.6. The group founder is always listed at the top and is marked with a distinctive icon. If the founder has paid their debt, the status card displays the message “All debt paid.”

   When a group debt is created, the system automatically divides the total amount equally among all group members. Until a user accepts the debt request, their status remains “Pending.” No payments can be made unless the debt is accepted. Additionally, a user cannot leave the group or delete it from their own application unless the debt is fully paid.

   This structure ensures that debts are managed responsibly and enhances the integrity of group interactions within the application. All current debt statuses are stored in the groupDebts collection on Firestore and reflected in real time on the user interface.

![image](https://github.com/user-attachments/assets/666561c7-19fa-4abc-8f77-807e01298917)

-------------------------------------------------------------------------------------------------

   In the Teilen application, in addition to financial transactions, a messaging infrastructure has been integrated to enhance user interaction. This infrastructure is implemented using the quickMessages collection in Firebase Firestore. Each conversation between two users is uniquely identified by a chatKey, which is generated using their respective UIDs. As illustrated in Figure 4.7, users can send direct messages to one another, and each message is stored with a timestamp and displayed in the user interface accordingly.

   Furthermore, when a user deletes a message, the system uses the deletedBy field to make it invisible only on that specific user's screen. This ensures that messages can be deleted with a mutual privacy principle, without affecting the visibility of the conversation for the other party.

![image](https://github.com/user-attachments/assets/1f330240-ea6e-4add-a29e-3029c59c0880)

-------------------------------------------------------------------------------------------------
   
   Additionally, the application presents the user’s current in-app balance and the main balance, which simulates a banking system, as distinct values. As illustrated in Figure 4.8, users can monitor both their balance (application balance) and main_balance (bank-like balance) in real time. This distinction provides flexibility in managing debt payment operations and contributes to the overall financial accuracy of the system.

   Data synchronization is handled via the Flutter interface, where transactions performed on the user interface are transmitted to the MySQL database through PHP APIs over HTTP. This structure ensures that both frontend and backend maintain consistent and up to date balance information, forming a reliable basis for managing debt settlement operations.

![image](https://github.com/user-attachments/assets/f7d02ff9-f276-451f-b74a-f2188af32d81)

-------------------------------------------------------------------------------------------------

   Finally, in order to ensure real-time and effective user interaction within the Teilen application, a notification system was developed using the Firebase Cloud Messaging (FCM) infrastructure. Through the use of Firebase Functions, the system is automatically triggered whenever a new document is added to the “notifications” or “friendRequests” collections in the Firestore database, sending push notifications to the corresponding users via FCM.

   Users can manage both general and specific types of notifications (such as individual debts, group debts, friend requests, and debt payments) through the “Notification Settings” screen in the application, as shown in Figure 4.9. These preferences are stored as boolean values (e.g., XnotificationsEnabled, XgroupDebtEnabled) in the users collection on Firestore. As a result, each user is able to customize their notification experience based on their personal preferences.

![image](https://github.com/user-attachments/assets/abec89a5-b26b-4f70-b6a3-bd29581b952a)







