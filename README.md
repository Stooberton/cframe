# Contraption Framework
A Lua framework for Garrysmod that is an attempt at an efficient and centralised method of gathering and storing information about constrained entities, eliminating the need for addons to track redundant information and crudely traversing a constraint network, and adding the ability to refer to a group of entities as one: a Contraption.

## The Contraption
CFrame generates a table to refer to a collection of constrained entities which is simply called a Contraption. A Contraption stores information from modules added to CFrame allowing groups of entities to be handled as if they were a single entity, making it much easier to work with.

### How it works
Rather than flood-filling a contraption every time data is to be collected, often done at intervals and being quite costly, CFrame monitors constraint/parent creation and deletion and either adds or removes data from the contraption on a case-by-case basis.

For example, if we wanted to know the mass of an entire contraption, the standard method is to iterate over every entity in the contraption (which can be several hundred, often with quite a lot of overlap) and return the number.
CFrame instead only runs when a constraint is added or deleted and performs a simple addition or subtration operation of the newly added or removed entity's mass to the contraptions stored mass and updates the stored amount. Now asking for the mass is a simple table lookup to return an existing number achieved by calling ```contraption.GetMass(Entity)```.
