unit UnitGLTFOpenGL;
{$ifdef fpc}
 {$mode delphi}
 {$ifdef cpu386}
  {$asmmode intel}
 {$endif}
 {$ifdef cpuamd64}
  {$asmmode intel}
 {$endif}
{$endif}
{$m+}

interface

uses SysUtils,Classes,Math,PasGLTF,dglOpenGL;

type EGLTFOpenGL=class(Exception);

     TGLTFOpenGL=class
      private
       type TAccessor=record
             public
              type TWorkBuffer=record
                    Active:boolean;
                    Handle:glUInt;
                    Data:TBytes;
                   end;
                   PWorkBuffer=^TWorkBuffer;
             public
              BufferView:TPasGLTFSizeInt;
              WorkBuffer:TWorkBuffer;
            end;
            PAccessor=^TAccessor;
            TAccessors=array of TAccessor;
            TBufferView=record
             Handle:glUInt;
             BufferView:TPasGLTF.TBufferView;
             Buffer:TPasGLTF.TBuffer;
            end;
            PBufferView=^TBufferView;
            TBufferViews=array of TBufferView;
            TVertex=packed record
             Position:TPasGLTF.TVector3;
             Normal:TPasGLTF.TVector3;
             Tangent:TPasGLTF.TVector4;
             TexCoord0:TPasGLTF.TVector2;
             TexCoord1:TPasGLTF.TVector2;
             Color0:TPasGLTF.TVector4;
             Joints0:TPasGLTF.TVector4;
             Joints1:TPasGLTF.TVector4;
             Weights0:TPasGLTF.TVector4;
             Weights1:TPasGLTF.TVector4;
            end;
            PVertex=^TVertex;
            TVertices=array of TVertex;
            TMesh=record
             public
              type TPrimitive=record
                    Vertices:TVertices;
                   end;
                   PPrimitive=^TPrimitive;
                   TPrimitives=array of TPrimitive;
             public
              Primitives:TPrimitives;
            end;
            PMesh=^TMesh;
            TMeshes=array of TMesh;
      private
       fDocument:TPasGLTF.TDocument;
       fReady:boolean;
       fAccessors:TAccessors;
       fBufferViews:TBufferViews;
       fMeshes:TMeshes;
      public
       constructor Create(const aDocument:TPasGLTF.TDocument); reintroduce;
       destructor Destroy; override;
       procedure InitializeResources;
       procedure FinalizeResources;
       procedure Draw(const aScene:TPasGLTFSizeInt=-1);
      published
       property Document:TPasGLTF.TDocument read fDocument;
     end;

implementation

const Epsilon=1e-8;

type TVector2=TPasGLTF.TVector2;
     PVector2=^TVector2;

     TVector3=TPasGLTF.TVector3;
     PVector3=^TVector3;

     TVector4=TPasGLTF.TVector4;
     PVector4=^TVector4;

     TMatrix=TPasGLTF.TMatrix4x4;
     PMatrix=^TMatrix;

function Vector2Add(const a,b:TVector2):TVector2;
begin
 result[0]:=a[0]+b[0];
 result[1]:=a[1]+b[1];
end;

function Vector2Sub(const a,b:TVector2):TVector2;
begin
 result[0]:=a[0]-b[0];
 result[1]:=a[1]-b[1];
end;

function Vector3Add(const a,b:TVector3):TVector3;
begin
 result[0]:=a[0]+b[0];
 result[1]:=a[1]+b[1];
 result[2]:=a[2]+b[2];
end;

function Vector3Sub(const a,b:TVector3):TVector3;
begin
 result[0]:=a[0]-b[0];
 result[1]:=a[1]-b[1];
 result[2]:=a[2]-b[2];
end;

function Vector3Cross(const a,b:TVector3):TVector3;
begin
 result[0]:=(a[1]*b[2])-(a[2]*b[1]);
 result[1]:=(a[2]*b[0])-(a[0]*b[2]);
 result[2]:=(a[0]*b[1])-(a[1]*b[0]);
end;

function Vector3Dot(const a,b:TVector3):TPasGLTFFloat;
begin
 result:=(a[0]*b[0])+(a[1]*b[1])+(a[2]*b[2]);
end;

function Vector3Normalize(const aVector:TVector3):TVector3;
var l:TPasGLTFFloat;
begin
 l:=sqrt(sqr(aVector[0])+sqr(aVector[1])+sqr(aVector[2]));
 if abs(l)>Epsilon then begin
  result[0]:=aVector[0]/l;
  result[1]:=aVector[1]/l;
  result[2]:=aVector[2]/l;
 end else begin
  result[0]:=0.0;
  result[1]:=0.0;
  result[2]:=0.0;
 end;
end;

function Vector3Neg(const aVector:TVector3):TVector3;
begin
 result[0]:=-aVector[0];
 result[1]:=-aVector[1];
 result[2]:=-aVector[2];
end;

function Vector3Scale(const aVector:TVector3;const aFactor:TPasGLTFFloat):TVector3;
begin
 result[0]:=aVector[0]*aFactor;
 result[1]:=aVector[1]*aFactor;
 result[2]:=aVector[2]*aFactor;
end;

function MatrixFromRotation(const aRotation:TVector4):TMatrix;
var qx2,qy2,qz2,qxqx2,qxqy2,qxqz2,qxqw2,qyqy2,qyqz2,qyqw2,qzqz2,qzqw2,l:TPasGLTFFloat;
    Rotation:TPasGLTF.TVector4;
begin
 l:=sqrt(sqr(aRotation[0])+sqr(aRotation[1])+sqr(aRotation[2])+sqr(aRotation[3]));
 Rotation[0]:=aRotation[0]/l;
 Rotation[1]:=aRotation[1]/l;
 Rotation[2]:=aRotation[2]/l;
 Rotation[3]:=aRotation[3]/l;
 qx2:=Rotation[0]+Rotation[0];
 qy2:=Rotation[1]+Rotation[1];
 qz2:=Rotation[2]+Rotation[2];
 qxqx2:=Rotation[0]*qx2;
 qxqy2:=Rotation[0]*qy2;
 qxqz2:=Rotation[0]*qz2;
 qxqw2:=Rotation[3]*qx2;
 qyqy2:=Rotation[1]*qy2;
 qyqz2:=Rotation[1]*qz2;
 qyqw2:=Rotation[3]*qy2;
 qzqz2:=Rotation[2]*qz2;
 qzqw2:=Rotation[3]*qz2;
 result[0]:=1.0-(qyqy2+qzqz2);
 result[1]:=qxqy2+qzqw2;
 result[2]:=qxqz2-qyqw2;
 result[3]:=0.0;
 result[4]:=qxqy2-qzqw2;
 result[5]:=1.0-(qxqx2+qzqz2);
 result[6]:=qyqz2+qxqw2;
 result[7]:=0.0;
 result[8]:=qxqz2+qyqw2;
 result[9]:=qyqz2-qxqw2;
 result[10]:=1.0-(qxqx2+qyqy2);
 result[11]:=0.0;
 result[12]:=0.0;
 result[13]:=0.0;
 result[14]:=0.0;
 result[15]:=1.0;
end;

function MatrixFromScale(const aScale:TVector3):TMatrix;
begin
 result[0]:=aScale[0];
 result[1]:=0.0;
 result[2]:=0.0;
 result[3]:=0.0;
 result[4]:=0.0;
 result[5]:=aScale[1];
 result[6]:=0.0;
 result[7]:=0.0;
 result[8]:=0.0;
 result[9]:=0.0;
 result[10]:=aScale[2];
 result[11]:=0.0;
 result[12]:=0.0;
 result[13]:=0.0;
 result[14]:=0.0;
 result[15]:=1.0;
end;

function MatrixFromTranslation(const aTranslation:TVector3):TMatrix;
begin
 result[0]:=1.0;
 result[1]:=0.0;
 result[2]:=0.0;
 result[3]:=0.0;
 result[4]:=0.0;
 result[5]:=1.0;
 result[6]:=0.0;
 result[7]:=0.0;
 result[8]:=0.0;
 result[9]:=0.0;
 result[10]:=1.0;
 result[11]:=0.0;
 result[12]:=aTranslation[0];
 result[13]:=aTranslation[1];
 result[14]:=aTranslation[2];
 result[15]:=1.0;
end;

function MatrixMul(const a,b:TMatrix):TMatrix;
begin
 result[0]:=(a[0]*b[0])+(a[1]*b[4])+(a[2]*b[8])+(a[3]*b[12]);
 result[1]:=(a[0]*b[1])+(a[1]*b[5])+(a[2]*b[9])+(a[3]*b[13]);
 result[2]:=(a[0]*b[2])+(a[1]*b[6])+(a[2]*b[10])+(a[3]*b[14]);
 result[3]:=(a[0]*b[3])+(a[1]*b[7])+(a[2]*b[11])+(a[3]*b[15]);
 result[4]:=(a[4]*b[0])+(a[5]*b[4])+(a[6]*b[8])+(a[7]*b[12]);
 result[5]:=(a[4]*b[1])+(a[5]*b[5])+(a[6]*b[9])+(a[7]*b[13]);
 result[6]:=(a[4]*b[2])+(a[5]*b[6])+(a[6]*b[10])+(a[7]*b[14]);
 result[7]:=(a[4]*b[3])+(a[5]*b[7])+(a[6]*b[11])+(a[7]*b[15]);
 result[8]:=(a[8]*b[0])+(a[9]*b[4])+(a[10]*b[8])+(a[11]*b[12]);
 result[9]:=(a[8]*b[1])+(a[9]*b[5])+(a[10]*b[9])+(a[11]*b[13]);
 result[10]:=(a[8]*b[2])+(a[9]*b[6])+(a[10]*b[10])+(a[11]*b[14]);
 result[11]:=(a[8]*b[3])+(a[9]*b[7])+(a[10]*b[11])+(a[11]*b[15]);
 result[12]:=(a[12]*b[0])+(a[13]*b[4])+(a[14]*b[8])+(a[15]*b[12]);
 result[13]:=(a[12]*b[1])+(a[13]*b[5])+(a[14]*b[9])+(a[15]*b[13]);
 result[14]:=(a[12]*b[2])+(a[13]*b[6])+(a[14]*b[10])+(a[15]*b[14]);
 result[15]:=(a[12]*b[3])+(a[13]*b[7])+(a[14]*b[11])+(a[15]*b[15]);
end;

{ TGLTFModel }

constructor TGLTFOpenGL.Create(const aDocument:TPasGLTF.TDocument);
begin
 inherited Create;
 fDocument:=aDocument;
 fReady:=false;
 fAccessors:=nil;
 fBufferViews:=nil;
 fMeshes:=nil;
end;

destructor TGLTFOpenGL.Destroy;
begin
 FinalizeResources;
 inherited Destroy;
end;

procedure TGLTFOpenGL.InitializeResources;
 procedure InitializeBufferViews;
 var Index:TPasGLTFSizeInt;
     Current:PBufferView;
 begin
  SetLength(fBufferViews,fDocument.BufferViews.Count);
  for Index:=0 to fDocument.BufferViews.Count-1 do begin
   Current:=@fBufferViews[Index];
   Current^.BufferView:=fDocument.BufferViews[Index];
   if (Current^.BufferView.Buffer>=0) and
      (Current^.BufferView.Buffer<fDocument.Buffers.Count) then begin
    Current^.Buffer:=fDocument.Buffers[Current^.BufferView.Buffer];
    glGenBuffers(1,@Current^.Handle);
    glBindBuffer(glEnum(Current^.BufferView.Target),Current^.Handle);
    glBufferData(glEnum(Current^.BufferView.Target),Current^.BufferView.ByteLength,@PPasGLTFUInt8Array(Current^.Buffer.Data.Memory)^[Current^.BufferView.ByteOffset],GL_STATIC_DRAW);
    glBindBuffer(glEnum(Current^.BufferView.Target),0);
   end else begin
    Assert(false);
   end;
  end;
 end;
 procedure InitializeAccessors;
 var Index,
     ComponentCount,
     ComponentSize,
     ElementSize,
     SkipEvery,
     SkipBytes:TPasGLTFSizeInt;
     Current:PAccessor;
     Accessor:TPasGLTF.TAccessor;
 begin
  SetLength(fAccessors,fDocument.Accessors.Count);
  for Index:=0 to fDocument.Accessors.Count-1 do begin
   Current:=@fAccessors[Index];
   Accessor:=fDocument.Accessors[Index];
   ComponentCount:=Accessor.Type_.GetComponentCount;
   ComponentSize:=Accessor.ComponentType.GetSize;
   ElementSize:=ComponentSize*ComponentCount;
   SkipEvery:=0;
   SkipBytes:=0;
   case Accessor.ComponentType of
    TPasGLTF.TAccessor.TComponentType.SignedByte,
    TPasGLTF.TAccessor.TComponentType.UnsignedByte:begin
     case Accessor.Type_ of
      TPasGLTF.TAccessor.TType.Mat2:begin
       SkipEvery:=2;
       SkipBytes:=2;
       ElementSize:=8;
      end;
      TPasGLTF.TAccessor.TType.Mat3:begin
       SkipEvery:=3;
       SkipBytes:=1;
       ElementSize:=12;
      end;
     end;
    end;
    TPasGLTF.TAccessor.TComponentType.SignedShort,
    TPasGLTF.TAccessor.TComponentType.UnsignedShort:begin
     case Accessor.Type_ of
      TPasGLTF.TAccessor.TType.Mat3:begin
       SkipEvery:=6;
       SkipBytes:=4;
       ElementSize:=16;
      end;
     end;
    end;
   end;
   if Accessor.Sparse.Empty then begin
    Current^.BufferView:=Accessor.BufferView;
    if (Current^.BufferView<0) or (Current^.BufferView>=fDocument.BufferViews.Count) then begin
     raise EGLTFOpenGL.Create('Ups');
    end;
   end else begin
   end;
  end;
 end;
 procedure InitializeMeshes;
 var Index,
     PrimitiveIndex,
     AccessorIndex,
     IndexIndex,
     VertexIndex:TPasGLTFSizeInt;
     SourceMesh:TPasGLTF.TMesh;
     SourceMeshPrimitive:TPasGLTF.TMesh.TPrimitive;
     DestinationMesh:PMesh;
     DestinationMeshPrimitive:TMesh.PPrimitive;
     TemporaryPositions,
     TemporaryNormals,
     TemporaryBitangents:TPasGLTF.TVector3DynamicArray;
     TemporaryTangents,
     TemporaryColor0,
     TemporaryJoints0,
     TemporaryJoints1,
     TemporaryWeights0,
     TemporaryWeights1:TPasGLTF.TVector4DynamicArray;
     TemporaryTexCoord0,
     TemporaryTexCoord1:TPasGLTF.TVector2DynamicArray;
     TemporaryIndices,
     TemporaryTriangleIndices:TPasGLTFUInt32DynamicArray;
     Normal,Tangent,Bitangent,p1p0,p2p0:TVector3;
     p0,p1,p2:PVector3;
     t1t0,t2t0:TVector2;
     t0,t1,t2:PVector2;
     Area:TPasGLTFFloat;
 begin

  SetLength(fMeshes,fDocument.Meshes.Count);

  for Index:=0 to fDocument.Meshes.Count-1 do begin

   SourceMesh:=fDocument.Meshes.Items[Index];

   DestinationMesh:=@fMeshes[Index];

   SetLength(DestinationMesh.Primitives,SourceMesh.Primitives.Count);

   for PrimitiveIndex:=0 to SourceMesh.Primitives.Count-1 do begin

    SourceMeshPrimitive:=SourceMesh.Primitives.Items[PrimitiveIndex];

    DestinationMeshPrimitive:=@DestinationMesh.Primitives[PrimitiveIndex];

    begin
     // Load accessor data
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['POSITION'];
      if AccessorIndex>=0 then begin
       TemporaryPositions:=fDocument.Accessors[AccessorIndex].DecodeAsVector3Array(true);
      end else begin
       raise EGLTFOpenGL.Create('Missing position data');
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['NORMAL'];
      if AccessorIndex>=0 then begin
       TemporaryNormals:=fDocument.Accessors[AccessorIndex].DecodeAsVector3Array(true);
      end else begin
       TemporaryNormals:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['TANGENT'];
      if AccessorIndex>=0 then begin
       TemporaryTangents:=fDocument.Accessors[AccessorIndex].DecodeAsVector4Array(true);
      end else begin
       TemporaryTangents:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['TEXCOORD_0'];
      if AccessorIndex>=0 then begin
       TemporaryTexCoord0:=fDocument.Accessors[AccessorIndex].DecodeAsVector2Array(true);
      end else begin
       TemporaryTexCoord0:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['TEXCOORD_1'];
      if AccessorIndex>=0 then begin
       TemporaryTexCoord1:=fDocument.Accessors[AccessorIndex].DecodeAsVector2Array(true);
      end else begin
       TemporaryTexCoord1:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['COLOR_0'];
      if AccessorIndex>=0 then begin
       TemporaryColor0:=fDocument.Accessors[AccessorIndex].DecodeAsColorArray(true);
      end else begin
       TemporaryColor0:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['JOINTS_0'];
      if AccessorIndex>=0 then begin
       TemporaryJoints0:=fDocument.Accessors[AccessorIndex].DecodeAsVector4Array(true);
      end else begin
       TemporaryJoints0:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['JOINTS_1'];
      if AccessorIndex>=0 then begin
       TemporaryJoints1:=fDocument.Accessors[AccessorIndex].DecodeAsVector4Array(true);
      end else begin
       TemporaryJoints1:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['WEIGHTS_0'];
      if AccessorIndex>=0 then begin
       TemporaryWeights0:=fDocument.Accessors[AccessorIndex].DecodeAsVector4Array(true);
      end else begin
       TemporaryWeights0:=nil;
      end;
     end;
     begin
      AccessorIndex:=SourceMeshPrimitive.Attributes['WEIGHTS_1'];
      if AccessorIndex>=0 then begin
       TemporaryWeights1:=fDocument.Accessors[AccessorIndex].DecodeAsVector4Array(true);
      end else begin
       TemporaryWeights1:=nil;
      end;
     end;
    end;

    begin
     // load or generate vertex indices
     if SourceMeshPrimitive.Indices>=0 then begin
      TemporaryIndices:=fDocument.Accessors[SourceMeshPrimitive.Indices].DecodeAsUInt32Array(false);
     end else begin
      SetLength(TemporaryIndices,length(TemporaryPositions));
      for IndexIndex:=0 to length(TemporaryIndices)-1 do begin
       TemporaryIndices[IndexIndex]:=IndexIndex;
      end;
     end;
     case SourceMeshPrimitive.Mode of
      TPasGLTF.TMesh.TPrimitive.TMode.Triangles:begin
       TemporaryTriangleIndices:=TemporaryIndices;
      end;
      TPasGLTF.TMesh.TPrimitive.TMode.TriangleStrip:begin
       TemporaryTriangleIndices:=nil;
       // TODO
      end;
      TPasGLTF.TMesh.TPrimitive.TMode.TriangleFan:begin
       TemporaryTriangleIndices:=nil;
       // TODO
      end;
      else begin
       TemporaryTriangleIndices:=nil;
      end;
     end;
    end;

    begin
     // Generate missing data
     if length(TemporaryNormals)<>length(TemporaryPositions) then begin
      SetLength(TemporaryNormals,length(TemporaryPositions));
      for VertexIndex:=0 to length(TemporaryNormals)-1 do begin
       TemporaryNormals[VertexIndex]:=TPasGLTF.TDefaults.NullVector3;
      end;
      if length(TemporaryTriangleIndices)>0 then begin
       IndexIndex:=0;
       while (IndexIndex+2)<length(TemporaryTriangleIndices) do begin
        p0:=@TemporaryPositions[TemporaryTriangleIndices[IndexIndex+0]];
        p1:=@TemporaryPositions[TemporaryTriangleIndices[IndexIndex+1]];
        p2:=@TemporaryPositions[TemporaryTriangleIndices[IndexIndex+2]];
        Normal:=Vector3Cross(Vector3Sub(p1^,p0^),Vector3Sub(p2^,p0^)); // non-normalized weighted normal
        TemporaryNormals[TemporaryTriangleIndices[IndexIndex+0]]:=Vector3Add(TemporaryNormals[TemporaryTriangleIndices[IndexIndex+0]],Normal);
        TemporaryNormals[TemporaryTriangleIndices[IndexIndex+1]]:=Vector3Add(TemporaryNormals[TemporaryTriangleIndices[IndexIndex+1]],Normal);
        TemporaryNormals[TemporaryTriangleIndices[IndexIndex+2]]:=Vector3Add(TemporaryNormals[TemporaryTriangleIndices[IndexIndex+2]],Normal);
        inc(IndexIndex,3);
       end;
       for VertexIndex:=0 to length(TemporaryNormals)-1 do begin
        TemporaryNormals[VertexIndex]:=Vector3Normalize(TemporaryNormals[VertexIndex]);
       end;
      end;
     end;
     if length(TemporaryTexCoord0)<>length(TemporaryPositions) then begin
      SetLength(TemporaryTexCoord0,length(TemporaryPositions));
      for VertexIndex:=0 to length(TemporaryNormals)-1 do begin
       TemporaryTexCoord0[VertexIndex]:=PVector2(@TPasGLTF.TDefaults.NullVector3)^;
      end;
     end;
     if length(TemporaryTangents)<>length(TemporaryPositions) then begin
      SetLength(TemporaryTangents,length(TemporaryPositions));
      SetLength(TemporaryBitangents,length(TemporaryPositions));
      for VertexIndex:=0 to length(TemporaryTangents)-1 do begin
       PVector3(@TemporaryTangents[VertexIndex])^:=TPasGLTF.TDefaults.NullVector3;
       TemporaryBitangents[VertexIndex]:=TPasGLTF.TDefaults.NullVector3;
      end;
      if length(TemporaryTriangleIndices)>0 then begin
       IndexIndex:=0;
       while (IndexIndex+2)<length(TemporaryTriangleIndices) do begin
        p0:=@TemporaryPositions[TemporaryTriangleIndices[IndexIndex+0]];
        p1:=@TemporaryPositions[TemporaryTriangleIndices[IndexIndex+1]];
        p2:=@TemporaryPositions[TemporaryTriangleIndices[IndexIndex+2]];
        t0:=@TemporaryTexCoord0[TemporaryTriangleIndices[IndexIndex+0]];
        t1:=@TemporaryTexCoord0[TemporaryTriangleIndices[IndexIndex+1]];
        t2:=@TemporaryTexCoord0[TemporaryTriangleIndices[IndexIndex+2]];
        p1p0:=Vector3Sub(p1^,p0^);
        p2p0:=Vector3Sub(p2^,p0^);
        t1t0:=Vector2Sub(t1^,t0^);
        t2t0:=Vector2Sub(t2^,t0^);
        Normal:=Vector3Normalize(Vector3Cross(p1p0,p2p0));
        if Vector3Dot(TemporaryNormals[TemporaryTriangleIndices[IndexIndex+0]],Normal)<0.0 then begin
         Normal:=Vector3Neg(Normal);
        end;
        Area:=(t1t0[0]*t2t0[1])-(t2t0[0]*t1t0[1]);
        if IsZero(Area) then begin
         Tangent[0]:=0.0;
         Tangent[1]:=1.0;
         Tangent[2]:=0.0;
         Bitangent[0]:=1.0;
         Bitangent[1]:=0.0;
         Bitangent[2]:=0.0;
        end else begin
         Tangent[0]:=((t2t0[1]*p1p0[0])-(t1t0[1]*p2p0[0]))/Area;
         Tangent[1]:=((t2t0[1]*p1p0[1])-(t1t0[1]*p2p0[1]))/Area;
         Tangent[2]:=((t2t0[1]*p1p0[2])-(t1t0[1]*p2p0[2]))/Area;
         Bitangent[0]:=((t1t0[0]*p2p0[0])-(t2t0[0]*p1p0[0]))/Area;
         Bitangent[1]:=((t1t0[0]*p2p0[1])-(t2t0[0]*p1p0[1]))/Area;
         Bitangent[2]:=((t1t0[0]*p2p0[2])-(t2t0[0]*p1p0[2]))/Area;
        end;
{       Tangent[0]:=(t1t0[1]*p2p0[0])-(t2t0[1]*p1p0[0]);
        Tangent[1]:=(t1t0[1]*p2p0[1])-(t2t0[1]*p1p0[1]);
        Tangent[2]:=(t1t0[1]*p2p0[2])-(t2t0[1]*p1p0[2]);
        Bitangent[0]:=(t1t0[0]*p2p0[0])-(t2t0[0]*p1p0[0]);
        Bitangent[1]:=(t1t0[0]*p2p0[1])-(t2t0[0]*p1p0[1]);
        Bitangent[2]:=(t1t0[0]*p2p0[2])-(t2t0[0]*p1p0[2]);}
        if Vector3Dot(Vector3Cross(Bitangent,Tangent),Normal)<0.0 then begin
         Tangent:=Vector3Neg(Tangent);
         Bitangent:=Vector3Neg(Bitangent);
        end;
        PVector3(@TemporaryTangents[TemporaryTriangleIndices[IndexIndex+0]])^:=Vector3Add(PVector3(@TemporaryTangents[TemporaryTriangleIndices[IndexIndex+0]])^,Tangent);
        PVector3(@TemporaryTangents[TemporaryTriangleIndices[IndexIndex+1]])^:=Vector3Add(PVector3(@TemporaryTangents[TemporaryTriangleIndices[IndexIndex+1]])^,Tangent);
        PVector3(@TemporaryTangents[TemporaryTriangleIndices[IndexIndex+2]])^:=Vector3Add(PVector3(@TemporaryTangents[TemporaryTriangleIndices[IndexIndex+2]])^,Tangent);
        TemporaryBitangents[TemporaryTriangleIndices[IndexIndex+0]]:=Vector3Add(TemporaryBitangents[TemporaryTriangleIndices[IndexIndex+0]],Bitangent);
        TemporaryBitangents[TemporaryTriangleIndices[IndexIndex+1]]:=Vector3Add(TemporaryBitangents[TemporaryTriangleIndices[IndexIndex+1]],Bitangent);
        TemporaryBitangents[TemporaryTriangleIndices[IndexIndex+2]]:=Vector3Add(TemporaryBitangents[TemporaryTriangleIndices[IndexIndex+2]],Bitangent);
        inc(IndexIndex,3);
       end;
       for VertexIndex:=0 to length(TemporaryTangents)-1 do begin
        Normal:=TemporaryNormals[VertexIndex];
        Tangent:=Vector3Normalize(PVector3(@TemporaryTangents[VertexIndex])^);
        Tangent:=Vector3Normalize(Vector3Sub(Tangent,Vector3Scale(Normal,Vector3Dot(Tangent,Normal))));
        Bitangent:=Vector3Normalize(TemporaryBitangents[VertexIndex]);
        Bitangent:=Vector3Normalize(Vector3Sub(Bitangent,Vector3Scale(Normal,Vector3Dot(Bitangent,Normal))));
        PVector3(@TemporaryTangents[VertexIndex])^:=Tangent;
        if Vector3Dot(Vector3Cross(TemporaryNormals[VertexIndex],Tangent),Bitangent)<0.0 then begin
         TemporaryTangents[VertexIndex,3]:=-1.0;
        end else begin
         TemporaryTangents[VertexIndex,3]:=1.0;
        end;
       end;
      end;
     end;
    end;

   end;

  end;

 end;
begin
 if not fReady then begin
  InitializeBufferViews;
  InitializeMeshes;
  fReady:=true;
 end;
end;

procedure TGLTFOpenGL.FinalizeResources;
 procedure FinalizeBufferViews;
 var Index:TPasGLTFSizeInt;
     Current:PBufferView;
 begin
  for Index:=0 to length(fBufferViews)-1 do begin
   Current:=@fBufferViews[Index];
   glDeleteBuffers(1,@Current^.Handle);
  end;
 end;
 procedure FinalizeAccessors;
 var Index:TPasGLTFSizeInt;
     Current:PAccessor;
 begin
  for Index:=0 to length(fAccessors)-1 do begin
   Current:=@fAccessors[Index];
   if Current^.WorkBuffer.Active then begin
    glDeleteBuffers(1,@Current^.WorkBuffer.Handle);
   end;
  end;
 end;
begin
 if fReady then begin
  fReady:=false;
  FinalizeBufferViews;
 end;
end;

procedure TGLTFOpenGL.Draw(const aScene:TPasGLTFSizeInt=-1);
 procedure DrawNode(const aNode:TPasGLTF.TNode;const aMatrix:TMatrix);
 var Index:TPasGLTFSizeInt;
     Matrix:TMatrix;
 begin
  Matrix:=MatrixMul(
           aMatrix,
           MatrixMul(
            aNode.Matrix,
            MatrixMul(
             MatrixFromScale(aNode.Scale),
             MatrixMul(
              MatrixFromRotation(aNode.Rotation),
              MatrixFromTranslation(aNode.Translation)))));
  for Index:=0 to aNode.Children.Count-1 do begin
   DrawNode(fDocument.Nodes[aNode.Children.Items[Index]],Matrix);
  end;
 end;
var Index:TPasGLTFSizeInt;
    Scene:TPasGLTF.TScene;
begin
 if aScene<0 then begin
  Scene:=fDocument.Scenes[fDocument.Scene];
 end else begin
  Scene:=fDocument.Scenes[aScene];
 end;
 for Index:=0 to Scene.Nodes.Count-1 do begin
  DrawNode(fDocument.Nodes[Scene.Nodes.Items[Index]],TPasGLTF.TDefaults.IdentityMatrix);
 end;
end;

end.