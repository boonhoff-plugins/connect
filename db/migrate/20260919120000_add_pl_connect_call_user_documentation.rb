# frozen_string_literal: true

# AddPlConnectCallUserDocumentation
#
# User-facing documentation for the Connect plugin's calling feature (audio/
# video calls with optional screen sharing, for direct conversations as well
# as group/channel/team conference calls), added as a new child page under
# DocumentationItem ID 1044 ("Endbenutzer", under ID 503 "Deutsche
# Dokumentation") — language is derived from the ancestor chain (503 => "de"),
# per claude.md's DocumentationItem language rule. Placed under "Endbenutzer"
# (not "Entwickler") because this describes end-user usage, matching sibling
# pages like "Kalender" and "Widgets".
#
# NOTE: per claude.md ("Dokumentation synchron halten"), this migration file
# is corrected in place (not superseded by a new migration) whenever the
# feature it documents changes, so a fresh install always gets the current
# text. Already-migrated installations need this content re-applied - re-run
# via `bin/rails runner` calling `AddPlConnectCallUserDocumentation.new.up` or
# `bin/rails db:migrate:redo VERSION=20260919120000`.
class AddPlConnectCallUserDocumentation < ActiveRecord::Migration[8.1]
  PARENT_ID = 1044 # Endbenutzer
  DOC_NAME = 'connect_anrufe'
  EXTENSION_ITEM_UUID = 'f71cb033-72ca-45e7-b216-12b4b174f262--extension_item--20260828211521' # Plugin: Connect

  def up
    @tenant = Tenant.find_by(code: 'default') || Tenant.first
    return puts '  [SKIP] No tenant found.' unless @tenant

    parent = DocumentationItem.find_by(id: PARENT_ID)
    return puts "  [SKIP] DocumentationItem #{PARENT_ID} (Endbenutzer) not found." unless parent

    extension_item = ExtensionItem.find_by(uuid: EXTENSION_ITEM_UUID)

    @c = ControllerHelper.init_tenant(:default, {}, false, false)
    @c[:current_tenant] = @tenant

    item = DocumentationItem.find_or_initialize_by(parent_id: parent.id, name: DOC_NAME)
    result = item.save_element(c: @c, element: {
                                 parent_id: parent.id, parent_uuid: parent.uuid,
                                 tenant_id: @tenant.id, tenant_uuid: @tenant.uuid,
                                 extension_item_id: extension_item&.id, extension_item_uuid: extension_item&.uuid,
                                 name: DOC_NAME, title: 'Anrufe & Bildschirmfreigabe (Connect-Chat)', f_type: 'page', language: 'de',
                                 visibility: 'internal',
                                 decimal_position: 90.0,
                                 content: documentation_content
                               })

    if result[:successful]
      YamlHelper.update_yaml(c: @c, reference_model: DocumentationItem, reference_id: result[:element].id,
                             auto_translate: SYSTEM&.dig(:language, :auto_translate_in_another_yml_files))
      puts "  [OK] DocumentationItem '#{DOC_NAME}' unter ID #{PARENT_ID} erstellt/aktualisiert."
    else
      puts "  [ERROR] #{result[:successful_text]}"
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    parent = DocumentationItem.find_by(id: PARENT_ID)
    item = DocumentationItem.find_by(parent_id: parent&.id, name: DOC_NAME)
    if item
      item.destroy
      puts "  [OK] DocumentationItem '#{DOC_NAME}' entfernt."
    else
      puts "  [SKIP] DocumentationItem '#{DOC_NAME}' nicht gefunden."
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}#down: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  def documentation_content
    <<~'HTML'
      <h1>Anrufe & Bildschirmfreigabe (Connect-Chat)</h1>

      <p>
        Aus jeder <strong>Einzelunterhaltung</strong> (1:1-Chat) sowie aus jeder
        <strong>Gruppen-, Kanal- oder Team-Unterhaltung</strong> im Connect-Plugin heraus kann
        ein Audio- oder Video-Anruf gestartet werden, w&auml;hrend des Anrufs kann zus&auml;tzlich
        der eigene Bildschirm geteilt werden. Die Bedienelemente befinden sich oben im
        Chat-Fenster, sobald eine Unterhaltung ge&ouml;ffnet ist.
      </p>

      <h2>Einen Anruf starten</h2>
      <p>
        Zwei Buttons im Kopfbereich der Unterhaltung starten den Anruf:
      </p>
      <ul>
        <li><strong>Audioanruf</strong> &ndash; startet den Anruf zun&auml;chst nur mit Mikrofon.</li>
        <li><strong>Videoanruf</strong> &ndash; startet den Anruf zus&auml;tzlich mit Kamera.</li>
      </ul>
      <p>
        In einer <strong>Einzelunterhaltung</strong> erh&auml;lt der Gespr&auml;chspartner eine
        Einladung, die er annehmen oder ablehnen kann &ndash; der Anruf klingelt, bis er
        angenommen, abgelehnt oder zur&uuml;ckgenommen wird.
      </p>
      <p>
        In einer <strong>Gruppen-, Kanal- oder Team-Unterhaltung</strong> gibt es dagegen keine
        einzelne Person, die klingelt: Der Anruf wird sofort aktiv, alle anderen Mitglieder der
        Unterhaltung werden benachrichtigt und k&ouml;nnen jederzeit beitreten, solange der
        Anruf l&auml;uft &ndash; auch nachtr&auml;glich, ohne dass er daf&uuml;r neu gestartet
        werden m&uuml;sste. W&auml;hrend des Anrufs lassen sich Mikrofon und Kamera jederzeit
        einzeln stumm- bzw. abschalten.
      </p>

      <h2>Bildschirm teilen</h2>
      <p>
        W&auml;hrend eines laufenden Anrufs kann &uuml;ber den entsprechenden Button die
        Freigabe des eigenen Bildschirms (oder eines einzelnen Fensters/Tabs, je nach
        Browserauswahl) gestartet und wieder beendet werden. Die &uuml;brigen Teilnehmenden
        sehen die Freigabe anstelle des Kamerabilds.
      </p>

      <h2>Teilnehmerzahl bei Gruppenanrufen</h2>
      <p>
        Gruppen-, Kanal- und Team-Anrufe verbinden alle Teilnehmenden direkt und ohne
        zwischengeschalteten Medienserver miteinander (WebRTC-Mesh). Dieses Verfahren bleibt nur
        bis zu einer kleinen Teilnehmerzahl praktikabel und ist daher auf
        <strong>4&nbsp;Teilnehmende</strong> begrenzt &ndash; ein weiterer Beitritt wird
        abgelehnt, solange der Anruf bereits voll besetzt ist.
      </p>

      <h2>Datenschutz (DSGVO)</h2>
      <p>
        Es werden ausschlie&szlig;lich <strong>Metadaten</strong> zum Anruf gespeichert
        (Zeitpunkt, Dauer, Status, Mikrofon-/Kamera-/Bildschirm-Status je Teilnehmer) &ndash;
        Audio-, Video- und Bildschirminhalte selbst werden zu keinem Zeitpunkt auf dem Server
        gespeichert, sie werden ausschlie&szlig;lich direkt zwischen den Browsern der
        Teilnehmenden &uuml;bertragen (WebRTC). Zum Verbindungsaufbau wird die &ouml;ffentliche
        IP-Adresse jedes Teilnehmenden &uuml;ber einen STUN-/TURN-Server ausgetauscht &ndash;
        dies ist eine technisch notwendige Eigenschaft von WebRTC. Rechtsgrundlage ist dieselbe
        wie bei Chat-Nachrichten (Art.&nbsp;6 DSGVO, Erf&uuml;llung des
        Zusammenarbeitskontexts). Wird ein Benutzer im Rahmen der DSGVO-Bereinigung
        anonymisiert, werden seine Anruf-Teilnahmedatens&auml;tze entfernt bzw. seine
        Initiator-Kennung aus bestehenden Anruf-Datens&auml;tzen gel&ouml;scht.
      </p>

      <p>
        Die zugrundeliegende STUN-/TURN-Konfiguration, das Ein-/Ausschalten des Anruf-Features
        insgesamt sowie die maximale Teilnehmerzahl bei Gruppenanrufen lassen sich in der
        Verwaltung unter <a href="/lookup_item/tree_element/"><strong>Lookup Items</strong></a>
        anpassen (Gruppe <code>pl_connect_chat_item</code>, Felder
        <code>webrtc_calls_active</code>, <code>webrtc_stun_urls</code>,
        <code>webrtc_turn_urls</code>, <code>webrtc_turn_username</code>,
        <code>webrtc_turn_credential</code>, <code>webrtc_mesh_participant_limit</code>).
      </p>
    HTML
  end
end

