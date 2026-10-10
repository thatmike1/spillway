extends RefCounted
## Shared rigid-space operations. Velocities and normals are world-space.

static func portal_mapping(entry: Transform3D, exit: Transform3D) -> Transform3D:
	return exit * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * entry.affine_inverse()

static func rotate_vector(mapping: Transform3D, vector: Vector3) -> Vector3:
	return mapping.basis.orthonormalized() * vector

static func is_finite_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite()
