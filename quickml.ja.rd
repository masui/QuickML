=begin
index:eJ

= quickmlサーバ: 超お手軽なメーリングリストシステム

最終更新日: 2004-06-09 (公開日: 2002-02-12)

--

quickmlサーバは超お手軽なメーリングリストシステムです。
quickmlサーバを利用すれば、超お手軽なメーリングリストサービスを提供できます。

最新版は
((<URL:http://quickml.com/quickml/>))
から入手可能です。

== 新着情報

  * 2004-06-09: quickml 0.7 を公開
    * 細かいバグ修正をいくつか行いました。
  * 2004-02-11: quickml 0.6 を公開
    * Ruby 1.8 に対応しました
    * autotool 化しました
    * その他細かい修正をいくつか
  * 2002-03-04: quickml 0.5 を公開
    * 巨大なメールに対するエラー処理を修正
    * Ruby 1.6.7を必要とする (time.rbを使うため)
  * 2002-03-01: quickml 0.4 を公開
    * 他の MTA と共存できるようにした ((<with-mta.ja.rd|URL:with-mta.ja.html>))
    * ポート25番バインド後に root 権限を捨てるようにした (quickmlrc: :user, :group)
    * qmail の VERP に対応 (quickmlrc: :use_qmail_verp = true/false)
    * ライブラリを複数のファイルに分割
    * その他細かい修正をいくつか
  * 2002-02-19: quickml 0.3 を公開
    * エラーメールの自動処理の機能を導入
    * メッセージの言語を切り替える仕組みを導入
    * その他細かい修正をいくつか
  * 2002-02-12: quickml 0.2 を公開
    * 致命的なバグを修正 (String.toeuc でエラーが起きる)
    * その他細かい修正をいくつか
  * 2002-02-12: quickml 0.1 を公開

== 特長

  * 好きなアドレスのメーリングリストを超お手軽に作れる
  * 好きなサブドメインつきのメーリングリストを作れる
  * SMTPを喋るサーバとして動作する
  * メールの配送は別のメールサーバに任せる
  * Ruby によるシンプルな実装

== ダウンロード

GNU General Public License version 2 に従ったフリーソフトウェ
アとして公開します。完全に無保証です。

  * ((<URL:http://quickml.com/quickml/quickml-0.7.tar.gz>))
  * ((<URL:http://sourceforge.net/cvs/?group_id=111025>))

== 動作環境

ほとんどの Unixシステムで動作すると思います。Red Hat Linux
7.2 と NetBSD 1.5.1 で動作を確認しています。

== 必要なもの

  * ((<Ruby|URL:http://www.ruby-lang.org/>)) 1.6.7以上
  * Ruby 1.8.x を推奨

== インストール方法

標準のインストールなら

  % ./configure && make
  # make install # rootになってから

で完了です。必要に応じて configure に設定を与えます。

  --with-user=USER        quickml runs as USER [root]
  --with-group=GROUP      quickml runs as GROUP [root]
  --with-pidfile=FILE     PID is stored in FILE  [/var/run/quickml.pid]
  --with-logfile=FILE     Log is recorded in FILE [/var/log/quickml.log]
  --with-rubydir=DIR      Ruby library files go to DIR [guessed]


== 設定

標準のインストールでは、設定ファイルは 
/usr/local/etc/quickmlrc.sample にあります。設定項目はたくさんあり
ますが、変更の必要があるのは次の 3つくらいです。

=== :smtp_host

メールの配送を任せるメールサーバを指定します。

=== :domain

メーリングリストのアドレスの @マークの右側を指定します。

=== :postmaster

エラーメールを送るときの From: のアドレスを指定します。

== サーバの使い方

quickmlサーバは SMTPポート (25番) を利用するため root 権限で
実行する必要があります。

=== 起動
  # quickml-ctl start

=== 停止
  # quickml-ctl stop

=== 再起動
  # quickml-ctl restart

== メーリングリストの使い方

((<QuickMLの使い方|URL:http://quickml.com/usage.html>)) と
((<QuickMLのFAQ|URL:http://quickml.com/FAQ.html>)) のページ
を、 quickml.comの部分を自分のドメイン名に置き換えて読んでく
ださい。

== エラーメールの自動処理

配送用メールサーバとして 
((<qmail|URL:http://www.qmail.org/>)) またはXVERP に対応した
((<Postfix|URL:http://www.postfix.org/>)) を使っている場合は、
エラーメールの自動処理の機能が有効になります。配送用メールサー
バからエラーメールが 5通返ってきたアドレスをメーリングリスト
から自動的に削除します。
この値は quickmlrc の :auto_unsubscribe_count で変更可能です。

qmail の場合は quickmlrc で :use_qmail_verp = true と設定し
てください。Postfix の場合は設定不要です。

== サブドメイン機能

quickml は DNSの wildcard MX を利用して、好きなサブドメイン
つきのメーリングリストを作る機能があります。quickml のサブド
メイン機能を有効にするためには、あらゆるサブドメイン宛のメー
ルを、quickml サーバの動いているホストに配送する必要がありま
す。これには DNS の wildcard MX RR (Resource Record) を利用
します。

BIND の設定例を次に紹介します。quickmlサーバは、
ml.pitecan.com (192.168.0.1) で動いているものとします。

  $ORIGIN pitecan.com.
  @    IN MX 10 ml           ; 1
  *    IN MX 10 ml           ; 2
  ml   IN A     192.168.0.1  ; 3
       IN MX 10 ml           ; 4
  

=== 注釈

  (1) @pitecan.com 宛のメールを ml.pitecan.com に向ける
  (2) 任意の pitecan.com サブドメイン宛のメールを ml.pitecan.com に向ける
  (3) ml.pitecan.com の IPアドレスの定義
  (4) MX RR を定義

== メーリングリストの管理ファイル

標準のインストールでは /usr/local/var/lib/quickml に各メーリ
ングリストの管理ファイルが置かれます。基本的には次の 3つのファ
イルから構成されます。

  * foo: メーリングリストのメンバーリスト
  * foo,count: メーリングリストのシリアル番号
  * foo,keyword: サブメーリングリストのキーワード

=== 特殊な管理ファイル

これらの空ファイルを作成すると、特殊なメーリングリストを作る
ことができます。

  * foo,permanent: 消滅しないメーリングリスト
  * foo,forward: 誰でも投稿できるメーリングリスト
  * foo,unlimited: メンバー数に制限のないメーリングリスト
  * foo,config: メンバー数やメールサイズなどの制限を設定

== quickml-analog

quickml-analog は quickml のログを解析してグラフを作成するツー
ルです。gnuplot, ImageMagick, ghostscript が必要です。次のよ
うに実行して使います。

  % quickml-analog -i -o output-dir quickml.log

== quickmlサーバのメーリングリスト

quickmlサーバの
((<メーリングリスト|URL:http://namazu.org/~satoru/archives/quickml-server/>))
を作りました。
興味のある方はどうぞ。次のようなメールを送ると参加できます。

  Subject: 参加します
  To: quickml-server@quickml.com
  Cc: satoru@namazu.org

  本文に一言


== QuickMLの誕生

QuickML のアイディアは
((<高林哲|URL:http://namazu.org/~satoru//>))と
((<増井俊之|URL:http://pitecan.com/>))
の雑談から生まれました。quickmlサーバは増井のPerlによるプロ
トタイプを高林が Rubyで書き直したものです。サブドメイン機能
の実現方法については
((<竹内奏吾氏|URL:http://www.csl.sony.co.jp/person/sohgo/>))
から助言をもらいました。


--

- ((<Satoru Takabayashi|URL:http://namazu.org/~satoru/>)) -

=end
