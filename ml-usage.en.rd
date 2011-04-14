=begin

= quickml server: How to Use Mailing List Service

Last Modified: 2002-02-19 (Since: 2002-02-19)

--

== Creating a Mailing List

To create a mailing list, you can send a mail to quickml
server with an address of the mailing list you want to
create.

  Subject: Party!
  To: party@quickml.com                <- Address of ML you want to create
  From: satoru@example.com             <- Your address
  Cc: masui@example.com                <- Address of Other members

  I just created a mailing list        <- Body
  for our party. 

== Submitting a Mail

To submit a mail, you can send a mail to the address of the
mailing list as usual.

  Subject: How about today?                     
  To: party@quickml.com                <- Address of ML
  From: satoru@example.com             <- Your address

  How about today?                     <- Body

== Adding a Member

To add a member, you can send a mail to the mailing list
with Cc: including the address of the new member.

  Subject: Add Komatsu
  To: party@quickml.com                <- Address of ML
  From: satoru@example.com             <- Your address
  Cc: komatsu@example.com              <- Address of a new member

  I just invited Mr. Komatsu           <- Body
  to our party.

== Joining in a Mailing List

To join in a mailing list, you can send a mail to the
mailing list with Cc: including the member of the mailing
list.


  Subject: Let me join
  To: party@quickml.com                <- Address of ML
  From: tsuka@example.com              <- Your address
  Cc: masui@example.com                <- Address of a member

  Don't forget me!                     <- Body

== Unsubscribe

To unsubscribe from a mailing list, you can send a mail to
the mailing list with an empty message.

  Subject: Bye!
  To: party@quickml.com                <- Address of ML
  From: satoru@example.com             <- Your address

                                       <- Empty body

== Removing a Member

To remove a member from a mailing list (usually unreachable
address), you can send a mail to the mailing list with an
empty message and Cc: including the address of the member.

  Subject: Remove an unreachable member
  To: party@quickml.com                <- Address of ML
  From: satoru@example.com             <- Your address
  Cc: fugo-masui@example..com          <- Address to remove

                                       <- Empty body

== Returning to a Mailing List

To return to a mailing list, you can send a mail to the
mailing list as usual.

  Subject: I'm back!
  To: party@quickml.com                <- Address of ML
  From: satoru@example.com             <- Your address

  I'm back!                            <- Body

== Deleting a Mailing List

A mailing list automatically closed when all members
unsubscribe.

== Automatic Deletion of a Mailing List

A mailing list automatically closes if there is no mails
submitted in 31 days.

--

- ((<Satoru Takabayashi|URL:http://namazu.org/~satoru/>)) -

=end
