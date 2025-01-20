(component
 :Ldap.Resolver.Core
 {:clj-import
  (quote [(:require [agentlang.util.logger :as log]
              [agentlang.component :as cn]
              [agentlang.evaluator :as ev]
              [clj-ldap.client :as ldap])])})

(def ^:private ldap-conn (atom nil))

(def ^:private log-prefix "Ldap.Resolver.Core: ")

(entity
 :Config
 {:meta {:inherits :Agentlang.Kernel.Lang/Config}
  :Host :String
  :Port {:type :Int :optional true}
  :BindDn :String
  :Password :String})

(defn init-ldap []
  (let [config (ev/fetch-model-config-instance :Ldap.Resolver)
        conn (ldap/connect
              {:host (:Host config)
               :port (or (:Port config) 389)
               :bind-dn (:BindDn config)
               :password (:Password config)})]
    (log/info (str log-prefix "init-ldap: initialized"))
    (reset! ldap-conn conn))
  true)

(defn- process-eq-op [op]
  (str "(" (name (second op)) "=" (last op) ")"))

(defn query-clause-to-ldap-filter [clause object-class]
  (let [obj-class-str (str "(objectClass=" object-class ")")]
    (cond
      (or (= clause :*) (nil? (seq clause)))
      (if object-class obj-class-str "(&)")
      :else
      (let [op (first clause)]
        (case op
          (:or :and)
          (let [s (case op :or "|" :and "&")]
            (str "(" s
                 (when object-class obj-class-str)
                 (apply
                  str
                  (mapv process-eq-op (rest clause))) ")"))
          (process-eq-op clause))))))

(defn ldap-query [[entity-name {clause :where} :as param]]
  (let [ent-meta (cn/fetch-meta entity-name)
        objectClass (:objectClass ent-meta)
        base (:base ent-meta)]
    (log/info (str "ldap-query: " entity-name " - " clause " - " objectClass " - " base))
    (let [f (query-clause-to-ldap-filter clause objectClass)]
      (log/info (str log-prefix "ldap-query filter:" f))
      (try
        (let [results (ldap/search @ldap-conn base
                                   {:filter f
                                    :scope :sub})
              records (map #(dissoc % :objectClass) results)]
          (log/info (str log-prefix "ldap-query results: " (count records) " total"))
          (mapv (partial cn/make-instance entity-name) records))
        (catch Exception ex
          (log/error (str log-prefix "query exception: " param " - response: " ex))
          (throw ex))))))

(defn ldap-on-set-path [[tag path]]
  (when (= tag :override)
    (-> path cn/disable-post-events cn/with-external-schema))
  path)

(resolver
 :Ldap.Resolver.Core/Resolver
 {:require {:pre-cond init-ldap}
  :with-methods
  {:query ldap-query
   :on-set-path ldap-on-set-path}})
