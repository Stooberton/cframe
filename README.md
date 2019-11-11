# Contraption Framework
A Lua framework for Garrysmod that is an attempt at an efficient and centralised method of gathering and storing information about constrained entities, eliminating the need for addons to track redundant information and crudely traversing a constraint network, and adding the ability to refer to a group of entities as one object: a contraption.

## The Contraption
Contraption Framework generates a table object to reference a group of constrained entities; This is referred to as a contraption.
Rather than flood-filling a contraption every time data is to be collected, often done at intervals and being quite costly, CFrame monitors constraint/parent creation and deletion and either adds or removes data from the contraption on a case-by-case basis. This allows for low-cost and real time results instead of the typical time-delayed or buffered systems set up in other addons, while also avoiding the need for flood filling almost entirely.

In effect, a contraption is any 2+ entities constrained together. Constraints an entity has to itself are ignored, such as ropes or keepuprights.

The behavior of Contraption Framework is currently captured in five hooks, with some minor additional nuance:
`CFrame Create` will be run when a contraption is generated. This happens when two entities are constrained together for the first time, at which point they will both immediately be connected to the contraption and two instances of `CFrame InitEntity` and `CFrame Connect` will run. Redundant constraints between entities within a contraption will not cause the connection hook to run again. If an entity is disconnected entirely from a contraption, the contraption table will update to reflect this and additionally call `CFrame Disconnect`. In the event that this entity was also the last in the contraption `CFrame Destroy` will be called immediately afterwards when the contraption table is removed.
Currently there is no distinct behavior for a contraption being split or merged. If two entities of existing contraptions are connected together the contraptions will be merged. The smaller of the two contraptions will have all of its entities popped and then appended to the larger contraption (calling `CFrame Disconnect` and `CFrame Connect` respectively) until the smaller is empty and finally destroyed, calling `CFrame Destroy`. When a contraption is split, one side will flood fill and generate a new contraption with one side migrating to the new contraption in the same manner as when contraptions are merged, with each entity being popped from the old and appended to the new.

# Addon Developers
  Note that this section may be incomplete.
## Modules for Contraption Framework

Contraption framework will automatically include all files contained within `<youraddon>/cframework/modules`, and will mount all files contained within and send files prefixed with `cl_` to clients. This is entirely optional and primarily useful for an addon whose sole purpose is to be a module for CFrame. Primary interaction with CFrame can be achieved through the provided hooks. The included mass module serves as an example.

## Contraption Framework Hooks
`CFrame Initialize`
`CFrame PhysChange`
`CFrame Create`
`CFrame Destroy`
`CFrame InitEntity`
`CFrame Connect` 
`CFrame Disconnect`
  
## Additional Hooks
Convenience hooks not used by contraption framework, but made convenient by contraption frameworks existing monitoring of constraints

`OnConstraintCreated`
`OnConstraintRemoved`
`OnParent`
`OnUnparent`

## Library functions
`cframe.GetAll()`
`cframe.Get(Entity)`
`cframe.GetConstraintTypes()`
`cframe.AddConstraint(Class)`
`cframe.RemoveConstraint(Class)`
`cframe.HasConstraints(Entity)`
