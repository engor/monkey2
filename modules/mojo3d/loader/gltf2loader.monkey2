
Namespace mojo3d.gltf2

Private

Class Gltf2Loader
	
	Method New( asset:Gltf2Asset,dir:String )
		
		_asset=asset
		_dir=dir
	End
	
	Method LoadMesh:Mesh()
		
		Local mesh:=New Mesh
		
		For Local node:=Eachin _asset.scene.nodes

			LoadMesh( node,mesh,Null )
		Next
		
		Return mesh
	End
	
	Method LoadModel:Model()

		Local mesh:=New Mesh
		
		Local materials:=New Stack<Material>
		
		For Local node:=Eachin _asset.scene.nodes
		
			LoadMesh( node,mesh,materials )
		Next
		
		Local model:=New Model
		
		model.Mesh=mesh
		
		model.Materials=materials.ToArray()
		
		Return model
	End
	
	Method LoadBonedModel:Model()
		
		Local pivot:=New Model
		
		For Local node:=Eachin _asset.scene.nodes
			
			LoadBonedModel( node,pivot )
		Next
		
		LoadAnimator( pivot )
		
		LoadBones()
		
		For Local node:=Eachin _asset.scene.nodes
			
			LoadBonedMesh( node )
		Next
		
		Return pivot
	End

	Private
	
	Alias IndexType:UInt
	
	Field _asset:Gltf2Asset
	Field _dir:String
	
	Field _data:=New StringMap<DataBuffer>
	Field _textureCache:=New Map<Gltf2Texture,Texture>
	Field _materialCache:=New Map<Gltf2Material,Material>
	
	Field _nodeIds:=New Map<Gltf2Node,Int>
	Field _entityIds:=New Map<Entity,Int>
	Field _entities:=New Stack<Entity>
	
	Field _bones:Model.Bone[]
	
	Method GetData:UByte Ptr( uri:String )
		Local data:=_data[uri]
		If Not data
			data=DataBuffer.Load( _dir+uri )
			_data[uri]=data
		Endif
		Return data.Data
	End
	
	Method GetData:UByte Ptr( buffer:Gltf2Buffer )
		Return GetData( buffer.uri )
	End
	
	Method GetData:UByte Ptr( bufferView:Gltf2BufferView )
		Return GetData( bufferView.buffer )+bufferView.byteOffset
	End
	
	Method GetData:UByte Ptr( accessor:Gltf2Accessor )
		Return GetData( accessor.bufferView )+accessor.byteOffset
	End
	
	Method GetTexture:Texture( texture:Gltf2Texture )
		
		If Not texture Return Null
		
		If _textureCache.Contains( texture ) Return _textureCache[texture]
		
		Local flags:=TextureFlags.Filter|TextureFlags.Mipmap|TextureFlags.WrapS|TextureFlags.WrapT
		
		Local tex:=Texture.Load( _dir+texture.source.uri,flags )
		
'		Print "Opened texture:"+_dir+texture.source.uri
		
		_textureCache[texture]=tex
		Return tex
	End
	
	Method GetMaterial:Material( material:Gltf2Material,textured:Bool,boned:Bool )
		
		If Not material Return New PbrMaterial( Color.Magenta,0,1,boned )
		
		If _materialCache.Contains( material ) Return _materialCache[material]
		
		Local colorTexture:Texture
		Local metallicRoughnessTexture:Texture
		Local occlusionTexture:Texture
		Local emissiveTexture:Texture
		Local normalTexture:Texture
		
		If textured
			colorTexture=GetTexture( material.baseColorTexture )
			metallicRoughnessTexture=GetTexture( material.metallicRoughnessTexture )
			occlusionTexture=GetTexture( material.occlusionTexture )
			emissiveTexture=GetTexture( material.emissiveTexture )
			normalTexture=GetTexture( material.normalTexture )
		Endif
			
		Local mat:=New PbrMaterial( boned )

		mat.ColorFactor=New Color( material.baseColorFactor.x,material.baseColorFactor.y,material.baseColorFactor.z )
		mat.MetalnessFactor=material.metallicFactor
		mat.RoughnessFactor=material.roughnessFactor

		If colorTexture mat.ColorTexture=colorTexture
		If metallicRoughnessTexture mat.MetalnessTexture=metallicRoughnessTexture ; mat.RoughnessTexture=metallicRoughnessTexture
		If occlusionTexture mat.OcclusionTexture=occlusionTexture
		If emissiveTexture 
			mat.EmissiveTexture=emissiveTexture
 			If material.emissiveFactor<>Null
				mat.EmissiveFactor=New Color( material.emissiveFactor.x,material.emissiveFactor.y,material.emissiveFactor.z )
			Else
				mat.EmissiveFactor=Color.White
			Endif
		Else If material.emissiveFactor<>Null
			mat.EmissiveTexture=Texture.ColorTexture( Color.White )
			mat.EmissiveFactor=New Color( material.emissiveFactor.x,material.emissiveFactor.y,material.emissiveFactor.z )
		Endif
		
		If normalTexture mat.NormalTexture=normalTexture
			
		_materialCache[material]=mat
		Return mat
	End

	Method FlipMatrix:Mat4f( matrix:Mat4f )
		matrix.i.z=-matrix.i.z
		matrix.j.z=-matrix.j.z
		matrix.k.x=-matrix.k.x
		matrix.k.y=-matrix.k.y
		matrix.t.z=-matrix.t.z
		Return matrix
	End
	
	Method GetMatrix:Mat4f( node:Gltf2Node )
		
		Local matrix:=FlipMatrix( node.matrix )
		
		Return node.parent ? GetMatrix( node.parent ) * matrix Else matrix
	End
	
	Method LoadPrimitive:Mesh( prim:Gltf2Primitive )
		
		'some sanity checking!
		'
		If prim.mode<>4
			Print "Gltf invalid mesh mode:"+prim.mode
			Return Null
		Endif
		
		If Not prim.indices
			Print "Gltf mesh has no indices"
			Return Null
		Endif

		If prim.POSITION.componentType<>GLTF_FLOAT Or prim.POSITION.type<>"VEC3"
			Print "Gltf nesh has invalid POSITION data type"
			Return Null
		Endif
		
		If Not prim.indices Or (prim.indices.componentType<>GLTF_UNSIGNED_SHORT And prim.indices.componentType<>GLTF_UNSIGNED_INT) Or prim.indices.type<>"SCALAR" 
			Print "Gltf mesh has invalid index data"
			Return Null
		Endif
		
		Local vcount:=prim.POSITION.count
		Local vertices:=New Vertex3f[vcount]

		Local datap:=GetData( prim.POSITION )
		Local stride:=prim.POSITION.bufferView.byteStride ?Else 12
		For Local i:=0 Until vcount
			vertices[i].position=Cast<Vec3f Ptr>( datap )[0]
			vertices[i].position.z=-vertices[i].position.z
			datap+=stride
		Next
		
		If prim.NORMAL
			If prim.NORMAL.componentType=GLTF_FLOAT And prim.NORMAL.type="VEC3"
'				Print "Gltf2 primitive has normals"
				Local datap:=GetData( prim.NORMAL )
				Local stride:=prim.NORMAL.bufferView.byteStride ?Else 12
				For Local i:=0 Until vcount
					vertices[i].normal=Cast<Vec3f Ptr>( datap )[0]
					vertices[i].normal.z=-vertices[i].normal.z
					datap+=stride
				Next
			Endif
		Endif
		
		If prim.TEXCOORD_0
			If prim.TEXCOORD_0.componentType=GLTF_FLOAT And prim.TEXCOORD_0.type="VEC2"
'				Print "Gltf2 primitive has texcoords"
				Local datap:=GetData( prim.TEXCOORD_0 )
				Local stride:=prim.TEXCOORD_0.bufferView.byteStride ?Else 8
				For Local i:=0 Until vcount
					vertices[i].texCoord0=Cast<Vec2f Ptr>( datap )[0]
					datap+=stride
				Next
			Endif
		Endif
		
		If prim.JOINTS_0
			Local datap:=GetData( prim.JOINTS_0 )
			If prim.JOINTS_0.componentType=GLTF_UNSIGNED_SHORT And prim.JOINTS_0.type="VEC4"
'				Print "Primitive has ushort joints"
				Local stride:=prim.JOINTS_0.bufferView.byteStride ?Else 8
				For Local i:=0 Until vcount
					Local cptr:=Cast<UShort Ptr>( datap )
					vertices[i].bones=cptr[3] Shl 24 | cptr[2] Shl 16 | cptr[1] Shl 8 | cptr[0]
					datap+=stride
				Next
			Else If prim.JOINTS_0.componentType=GLTF_UNSIGNED_BYTE And prim.JOINTS_0.type="VEC4"
'				Print "Primitive has ubyte joints"
				Local stride:=prim.JOINTS_0.bufferView.byteStride ?Else 4
				For Local i:=0 Until vcount
					Local cptr:=Cast<UByte Ptr>( datap )
					vertices[i].bones=cptr[3] Shl 24 | cptr[2] Shl 16 | cptr[1] Shl 8 | cptr[0]
					datap+=stride
				Next
			Endif
		Endif
		
		If prim.WEIGHTS_0
			Local datap:=GetData( prim.WEIGHTS_0 )
			If prim.WEIGHTS_0.componentType=GLTF_FLOAT And prim.WEIGHTS_0.type="VEC4"
'			Print "Primitive has float weights"
				Local stride:=prim.WEIGHTS_0.bufferView.byteStride ?Else 16
				For Local i:=0 Until vcount
					vertices[i].weights=Cast<Vec4f Ptr>( datap )[0]
					datap+=stride
				Next
			Endif
		Endif
		
		Local icount:=prim.indices.count
		Local indices:=New IndexType[icount]

		datap=GetData( prim.indices )
		stride=prim.indices.bufferView.byteStride
		If prim.indices.componentType=GLTF_UNSIGNED_SHORT
			stride=stride ?Else 2
			For Local i:=0 Until icount Step 3
				indices[i+0]=Cast<UShort Ptr>( datap )[0]
				indices[i+2]=Cast<UShort Ptr>( datap )[1]
				indices[i+1]=Cast<UShort Ptr>( datap )[2]
				datap+=stride*3
			Next
		Else
			stride=stride ?Else 4
			For Local i:=0 Until icount Step 3
				indices[i+0]=Cast<UInt Ptr>( datap )[0]
				indices[i+2]=Cast<UInt Ptr>( datap )[1]
				indices[i+1]=Cast<UInt Ptr>( datap )[2]
				datap+=stride*3
			Next
		Endif
		
		Return New Mesh( vertices,indices )
	End
	
	Method LoadMesh( node:Gltf2Node,mesh:Mesh,materials:Stack<Material> )
		
		If node.mesh
			
			Local matrix:=New AffineMat4f( GetMatrix( node ) )

			For Local prim:=Eachin node.mesh.primitives
				
				Local pmesh:=LoadPrimitive( prim )
				
				pmesh.TransformVertices( matrix )
				
				If materials
					
					Local textured:=prim.TEXCOORD_0<>Null
					
					materials.Add( GetMaterial( prim.material,textured,False ) )
					
					mesh.AddMesh( pmesh,mesh.NumMaterials )
				Else
				
					mesh.AddMesh( pmesh )
				Endif
				
			Next
			
		Endif
		
		For Local child:=Eachin node.children
			
			LoadMesh( child,mesh,materials )
		Next
	
	End
	
	Method LoadBonedModel:Model( node:Gltf2Node,parent:Model )

		Local model:=New Model( parent )
		
		model.Name=node.name
		
		model.LocalMatrix=New AffineMat4f( FlipMatrix( node.matrix ) )
		
		Local id:=_entities.Length
		_entities.Add( model )
		_entityIds[model]=id
		_nodeIds[node]=id
		
		For Local child:=Eachin node.children
			
			LoadBonedModel( child,model )
		Next
		
		Return model
	End
	
	Method LoadBonedMesh( node:Gltf2Node )
		
		If node.mesh

			Local mesh:=New Mesh
			
			Local materials:=New Stack<Material>
			
			For Local prim:=Eachin node.mesh.primitives
				
				Local pmesh:=LoadPrimitive( prim )
				
				mesh.AddMesh( pmesh,mesh.NumMaterials )
				
				Local boned:=prim.JOINTS_0<>Null
				
				Local textured:=prim.TEXCOORD_0<>Null
				
				materials.Add( GetMaterial( prim.material,textured,boned ) )
			Next
			
			Local model:=Cast<Model>( _entities[_nodeIds[node]] )
		
			model.Mesh=mesh
			
			model.Materials=materials.ToArray()
			
			If node.mesh.primitives[0].JOINTS_0<>Null
				
				model.Bones=_bones
			Endif
			
		Endif
		
		For Local child:=Eachin node.children
			
			LoadBonedMesh( child )
		Next
	End
	
	Method LoadAnimation:Animation( ganimation:Gltf2Animation )
		
		Local gchannels:=ganimation.channels
		
		Local posKeys:=New Stack<PositionKey>[_entities.Length]
		Local rotKeys:=New Stack<RotationKey>[_entities.Length]
		Local sclKeys:=New Stack<ScaleKey>[_entities.Length]
		
		Local minTime:=10000.0,maxTime:=0.0
		
		For Local i:=0 Until gchannels.Length
			
			Local gchannel:=gchannels[i]
			
			If Not _nodeIds.Contains( gchannel.targetNode )
				Print "Gltf2Loader: gchannel.targetNode not found"
				Continue
			Endif
			
			Local entityId:=_nodeIds[gchannel.targetNode]

			Local sampler:=gchannel.sampler
			
			Local n:=sampler.input.count
			If Not n Continue
			
			If n<>sampler.output.count
				Print "Gltf2Loader: sampler.input.count<>sampler.output.count"
				continue
			End
			
			Local timep:=GetData( sampler.input )
			Local timeStride:=sampler.input.bufferView.byteStride ?Else 4

			minTime=Min( minTime,Cast<Float Ptr>(timep)[0] )
			maxTime=Max( maxTime,Cast<Float Ptr>(timep+(n-1)*timeStride)[0] )
				
			Select gchannel.targetPath
			Case "translation"
				
				Local keys:=New Stack<PositionKey>
				If posKeys[ entityId ] Print "OOPS!"
				posKeys[entityId]=keys

				Local datap:=GetData( sampler.output )
				Local dataStride:=sampler.output.bufferView.byteStride ?Else 12
				
				For Local i:=0 Until n

					Local v:=Cast<Vec3f Ptr>( datap )[0]
					
					v.z=-v.z
					
					keys.Add( New PositionKey( Cast<Float Ptr>( timep )[0],v ) )
					
					timep+=timeStride
					datap+=dataStride
				Next
			
			Case "rotation"

				Local keys:=New Stack<RotationKey>
				If rotKeys[entityId] Print "OOPS!"
				rotKeys[entityId]=keys
				
				Local datap:=GetData( sampler.output )
				Local dataStride:=sampler.output.bufferView.byteStride ?Else 16
				
				For Local i:=0 Until n

					Local q:=Cast<Quatf Ptr>( datap )[0]
					
					q.v.x=-q.v.x
					q.v.y=-q.v.y
					q.w=-q.w
					
					keys.Add( New RotationKey( Cast<Float Ptr>( timep )[0],q ) )
					
					timep+=timeStride
					datap+=dataStride
				Next
				
			Case "scale"
				
				Local keys:=New Stack<ScaleKey>
				If sclKeys[entityId] Print "OOPS!"
				sclKeys[entityId]=keys
				
				Local datap:=GetData( sampler.output )
				Local dataStride:=sampler.output.bufferView.byteStride ?Else 12
				
				For Local i:=0 Until n

					Local v:=Cast<Vec3f Ptr>( datap )[0]
					
					keys.Add( New ScaleKey( Cast<Float Ptr>( timep )[0],v ) )
					
					timep+=timeStride
					datap+=dataStride
				Next
				
			Default
				
				Print "targetPath="+gchannel.targetPath+"?????"
			
			End
			
		Next
		
		Local duration:=maxTime-minTime
		
'		Print "animation:"+ganimation.name+" duration:"+duration
		
		Local channels:=New AnimationChannel[_entities.Length]
		
		For Local i:=0 Until channels.Length
			
			Local pkeys:=posKeys[i]?.ToArray()
			Local rkeys:=rotKeys[i]?.ToArray()
			Local skeys:=sclKeys[i]?.ToArray()
			
			For Local key:=Eachin pkeys
				key.Time-=minTime
			End
			For Local key:=Eachin rkeys
				key.Time-=minTime
			End
			For Local key:=Eachin skeys
				key.Time-=minTime
			End
			
'			If Not pkeys And Not rkeys And Not skeys 
'				Print "Yo1"
'			Else If Not pkeys Or Not rkeys Or Not skeys 
'				Print "Yo2"
'			Endif
			
'			Print "channel:"+_entities[i].Name+" keys:"+pkeys.Length
			
			channels[i]=New AnimationChannel( pkeys,rkeys,skeys )
		Next
		
		Local animation:=New Animation( ganimation.name,channels,duration,1,AnimationMode.Looping )
		
		Return animation
	End
	
	Method LoadAnimator:Animator( model:Model )
		
		If Not _asset.animations Return Null
		
		Local animations:=New Animation[_asset.animations.Length]
		
		For Local i:=0 Until animations.Length
			
			animations[i]=LoadAnimation( _asset.animations[i] )
		Next
		
		Local animator:=New Animator( model )

		animator.Animations.AddAll( animations )
		
		animator.Skeleton=_entities.ToArray()
		
		Return animator
	End
	
	Method LoadBones()
		
		If Not _asset.skins Return
		
		Local skin:=_asset.skins[0]
		
		Local datap:=GetData( skin.inverseBindMatrices )
		Local stride:=skin.inverseBindMatrices.bufferView.byteStride ?Else 64
		Local n:=skin.inverseBindMatrices.count
		
		If n<>skin.joints.Length
			Print "Invalid skin"
			Return
		Endif
		
		_bones=New Model.Bone[n]
		
'		Print "Loading "+n+" bones"
		
		For Local i:=0 Until n
			
			Local entity:=_entities[ _nodeIds[skin.joints[i]] ]
			Local matrix:=FlipMatrix( Cast<Mat4f Ptr>( datap )[0] )
			
			_bones[i].entity=entity
			_bones[i].offset=New AffineMat4f( matrix )
			
			datap+=stride
		Next
	End
	
End

Public

#rem monkeydoc @hidden
#End
Class Gltf2Mojo3dLoader Extends Mojo3dLoader

	Const Instance:=New Gltf2Mojo3dLoader

	Method LoadMesh:Mesh( path:String ) Override
	
		Local loader:=Open( path )
		If Not loader Return Null

		Local mesh:=loader.LoadMesh()
		
		Return mesh
	End

	Method LoadModel:Model( path:String ) Override
	
		Local loader:=Open( path )
		If Not loader Return Null

		Local model:=loader.LoadModel()
		
		Return model
	End

	Method LoadBonedModel:Model( path:String ) Override

		Local loader:=Open( path )
		If Not loader Return Null

		Local model:=loader.LoadBonedModel()
		
		Return model
	End
	
	Private
	
	Method Open:Gltf2Loader( path:String )
		
		If ExtractExt( path ).ToLower()<>".gltf" Return Null
			
		Local asset:=Gltf2Asset.Load( path )
		If Not asset Return Null
		
		Local loader:=New Gltf2Loader( asset,ExtractDir( path ) )
		
		Return loader
	End

End