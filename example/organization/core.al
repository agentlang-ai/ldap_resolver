(component
 :Organization.Core
 {:clj-import
  (quote [(:require [ldap.resolver.model])])})

(entity
 :Person
 {:uid {:type :String, :guid true}
  :dn :String
  :sn :String
  :mail :String
  :meta
  {:base "ou=People,dc=mydomain,dc=com"
   :objectClass "inetOrgPerson"}})

(dataflow
 :GetPersonByEmail
 {:Person
  {:mail? :GetPersonByEmail.Email}})

(resolver
 :resolver01
 {:type :Ldap.Resolver.Core/Resolver
  :paths [:Organization.Core/Person]})
