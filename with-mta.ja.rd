=begin

= quickmlサーバ: 他のMTAと共存させる方法

最終更新日: 2002-04-28 (公開日: 2002-04-28)


== quickmlサーバの設定

1. quickmlサーバを動かす Unixホストにユーザ quickml とグルー
プ quickml を作成する。

2. quickmlrc の設定を次のように設定する。

  Config = {
    :user => 'quickml', 
    :group => 'quickml',
    :port => 10025,
    :bind_address => "127.0.0.1",

== DNSの設定

動かしたいドメイン (例: foobar.com) の MX を quickml サーバ
が動いているホストに向ける。

== MTA の設定

=== qmail の場合

1. /var/qmail/control/rcpthosts に

  foobar.com 

を追加する。

2. /var/qmail/control/smtproutes に

  foobar.com:localhost:10025 

を追加する。

=== Postfix の場合

1. /etc/postfix/transport に

  foobar.com smtp:[localhost:10025]

を追加する。

2. /etc/postfix/main.cf に

  transport_maps = hash:/etc/transport

を追加し、次のコマンドを実行する。

  # postmap transport 
  # postfix reload

== 謝辞

この文書は
((<工藤拓氏|URL:http://cl.aist-nara.ac.jp/~taku-ku/>))
からいただいた情報を元にしています。

--

- ((<Satoru Takabayashi|URL:http://namazu.org/~satoru/>)) -

=end
