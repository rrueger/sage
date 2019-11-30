"""
Ideals in Tate algebra

The module gives tools for manipulating ideals in Tate algebras
and, in particular, provides an implementation of the Buchberger
algorithm in this context.

AUTHORS:

- Xavier Caruso, Thibaut Verron (2018-09)

"""

# ***************************************************************************
#    Copyright (C) 2018 Xavier Caruso <xavier.caruso@normalesup.org>
#                       Thibaut Verron <thibaut.verron@gmail.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#                  http://www.gnu.org/licenses/
# ***************************************************************************

from sage.rings.ideal import Ideal_generic
from sage.misc.cachefunc import cached_method

from sage.structure.richcmp import op_EQ, op_NE, op_LT, op_GT, op_LE, op_GE

from sage.structure.element cimport Element
from sage.rings.tate_algebra_element cimport TateAlgebraTerm
from sage.rings.tate_algebra_element cimport TateAlgebraElement
from heapq import heappush, heappop


class TateAlgebraIdeal(Ideal_generic):
    r"""
    Initialize a class for ideals in a Tate series algebra

    EXAMPLES::

        sage: R = Zp(3, prec=10, print_mode="digits")
        sage: A.<x,y> = TateAlgebra(R)
        sage: f = 3*x^2 + 5*x*y^2
        sage: g = 5*x^2*y + 3
        sage: I = A.ideal([f,g]); I
        Ideal (...0000000012*x*y^2 + ...00000000010*x^2, ...0000000012*x^2*y + ...00000000010) of Tate Algebra in x (val >= 0), y (val >= 0) over 3-adic Field with capped relative precision 10

    """

    #@cached_method
    def groebner_basis(self, prec=None, algorithm='buchberger-integral', verbose=0):
        r"""
        Compute a Groebner basis of the ideal

        INPUT:

        - ``prec`` -- an integer or ``None`` (default: ``None``), the precision
          at which the computations are carried. If ``None``, defaults to the
          algebra precision cap

        - ``algorithm`` -- a string (default: ``buchberger-integral``), the
          algorithm to use in the calculations; currently, only ``buchberger``
          and ``buchberger-integral`` are available.

        OUTPUT:

        The Groebner basis `(g_1,\dots,g_n)` of this ideal, uniquely determined
        by the following conditions::

        - it is minimal, in the sense that the leading coefficient of `g_i`
          does not divide the leading coefficient of `g_j` if `i \neq j`,

        - it is reduced, in the sense that each term of `g_i` is not divisible
          by leading term of `g_j` for `j \neq i` or the leading term of
          `\pi g_i` where `\pi` is the uniformizer,

        - it is normalized so that the leading coefficient of each `g_i` is
          a power of the uniformizer and moreover, if we are working over a Tate
          algebra (and not its ring of integers), each `g_i` has valuation `0`,

        - it is sorted, in the sense that the leading term of `g_i` is greater
          than the leading of `g_{i+1}` for all `i`.

        NOTE::

        The algorithm ``buchberger-integral`` first computes a Groebner basis
        of the ideal generated by the same generators over the ring of integers.

        The result of this method is cached.

        EXAMPLES::

            sage: R = Zp(3, prec=10, print_mode="digits")
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = 3*x^2 + 5*x*y^2
            sage: g = 5*x^2*y + 3
            sage: I = A.ideal([f,g])
            sage: I.groebner_basis()
            [...000000001*x^3 + ...222222222*y + O(3^9 * <x, y>),
             ...0000000001*x^2*y + ...1210121020 + O(3^10 * <x, y>),
             ...000000001*y^2 + ...210121020*x + O(3^9 * <x, y>)]

        The algorithm ``buchberger`` is faster than ``buchberger-integral``
        but may lose more precision::

            sage: R = Zp(2, 5, print_mode='digits')
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = x^2*y^6 + x^4 + 25*y^2 + 2*x^3*y^3 + 10*x*y^4 + 10*x^2*y
            sage: g = x^4*y^5 + x^5*y^2 + x^4 + 5*x^2*y + 2*x^5*y^4 + 2*x^6*y + 6*x^3*y^3
            sage: h = 2*x^6*y^4 + 2*x^4 + 4*x^5*y^2 + 8*x^8*y^2 + 8*x^7*y^3 + 8*x^6*y
            sage: I = A.ideal([f,g,h])
            sage: I.groebner_basis()
            [...0001*x^4 + O(2^4 * <x, y>), 
             ...0001*x^2*y + O(2^4 * <x, y>),
             ...0001*y^2 + O(2^4 * <x, y>)]
            sage: I.groebner_basis(algorithm='buchberger')
            [...001*x^4 + O(2^3 * <x, y>),
             ...001*x^2*y + O(2^3 * <x, y>),
             ...001*y^2 + O(2^3 * <x, y>)]

        TESTS::

            sage: I.groebner_basis(algorithm="F4")
            Traceback (most recent call last):
            ...
            NotImplementedError: only Buchberger algorithm is implemented so far

        """
        if prec is None:
            prec = self.ring().precision_cap()
        if algorithm == "buchberger":
            return _groebner_basis_buchberger(self, prec, False)
        elif algorithm == "buchberger-integral":
            return _groebner_basis_buchberger(self, prec, True)
        elif algorithm == "F5":
            return _groebner_basis_F5(self, prec, verbose=verbose)
        else:
            raise NotImplementedError("only Buchberger algorithm is implemented so far")

    def _contains_(self, x):
        r"""
        Return ``True`` if ``x`` lies in this ideal

        INPUT:

        - ``x`` -- a Tate series

        EXAMPLES::

            sage: R = Zp(3, 10)
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = 3*x^2 + 5*x*y^2
            sage: g = 5*x^2*y + 3
            sage: I = A.ideal([f,g])
            sage: f in I  # indirect doctest
            True
            sage: (f+g) in I  # indirect doctest
            True
            sage: (f+1) in I  # indirect doctest
            False

        TESTS::

            sage: I.random_element() in I
            True

        """
        rgb = self.groebner_basis()
        return (x % rgb).is_zero()

    def _contains_ideal(self, I):
        r"""
        Return ``True`` if ``I`` is contained in this ideal

        INPUT:

        - ``I`` -- an ideal in a Tate series algebra

        EXAMPLES::

            sage: R = Zp(3,prec=10,print_mode="digits")
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = 3*x^2 + 5*x*y^2
            sage: g = 5*x^2*y + 3
            sage: I = A.ideal([f,g])
            sage: A.ideal([f]) < I  # indirect doctest
            True
            sage: I < A.ideal([f])  # indirect doctest
            False
            sage: A.ideal([1]) < I  # indirect doctest
            False
            sage: I < A.ideal([1])  # indirect doctest
            True

        """
        rgb = self.groebner_basis()
        for f in I.gens():
            if not f in self:
                return False
        return True

    def _richcmp_(self, other, op):
        r"""
        Compare this ideal with ``other`` for the rich comparison
        operator ``op``

        INPUT:

        - ``other`` -- an ideal in a Tate series algebra

        - ``op`` -- a comparison operator

        EXAMPLES::

            sage: R = Zp(3, 10)
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = 3*x^2 + 5*x*y^2
            sage: g = 5*x^2*y + 3
            sage: I = A.ideal([f,g])
            sage: A.ideal([f]) < I
            True
            sage: I < A.ideal([f])
            False
            sage: A.ideal([1]) < I
            False
            sage: I < A.ideal([1])
            True
            sage: I <= A.ideal([f,g])
            True
            sage: I == A.ideal([f,g])
            True
            sage: I <= A.ideal([f])
            False
            sage: A.ideal([f]) <= I
            True
            sage: A.ideal([f]) == I
            False

        """
        if op == op_GT:
            return self._contains_ideal(other) and not other._contains_ideal(self)
        elif op == op_GE:
            return self._contains_ideal(other)
        elif op == op_EQ:
            return self._contains_ideal(other) and other._contains_ideal(self)
        elif op == op_NE:
            return not(self._contains_ideal(other) and other._contains_ideal(self))
        elif op == op_LE:
            return other._contains_ideal(self)
        elif op == op_LT:
            return other._contains_ideal(self) and not self._contains_ideal(other)

    def is_saturated(self):
        r"""
        Return ``True`` if this ideal is saturated.

        The ideal `I` is saturated if `\pi f \in I` implies `f \in I`
        for any `f` in the underlying ring. Here `\pi` denotes a
        uniformizer of the field of coefficients.

        .. NOTE::

            All ideals are saturated when `\pi` is invertible.

        EXAMPLES::

        Over classical Tate algebras (where `\pi` is invertible), this
        method always returns ``True``::

            sage: R = Zp(3, prec=10, print_mode="digits")
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = 3*x^2 + 5*x*y^2
            sage: g = 5*x^2*y + 3
            sage: A.ideal([f,g]).is_saturated()
            True
            sage: A.ideal([f,3*g]).is_saturated()
            True

        The test is only relevant over the rings of integers of Tate
        algebras::

            sage: Ao = A.integer_ring()
            sage: Io = Ao.ideal([f,g])
            sage: Io.is_saturated()
            False
            sage: Io.groebner_basis()
            [...0000000001*x^2*y + ...1210121020 + O(3^10 * <x, y>),
             ...0000000001*x*y^2 + ...1210121020*x^2 + O(3^10 * <x, y>),
             ...0000000010*x^3 + ...2222222220*y + O(3^10 * <x, y>),
             ...0000000010*y^2 + ...2101210200*x + O(3^10 * <x, y>)]

        Principal ideals are not always saturated::

            sage: Ao.ideal([3*f]).is_saturated()
            False

        """
        if self.ring().base_ring().is_field():
            return True
        gb = self.groebner_basis()
        for g in gb:
            if g.valuation() > 0:
                return False
        return True

    def saturate(self):
        r"""
        Return the ideal obtained by saturating this ideal.

        In other words, the result is the ideal

        .. MATH::

            (I:\pi^\infty) = \{f \in A : \exists n \in \mathbb{N}, \pi^n f \in I\}`

        where `A` is the underlying ring and `\pi` is the uniformizer of the
        field of coefficients.

        .. NOTE::

            When `\pi` is invertible in `A`, all ideals are saturated.

        EXAMPLES::

        Over classical Tate algebras (where `\pi` is invertible), this
        method always returns the same ideal::

            sage: R = Zp(3, prec=10, print_mode="digits")
            sage: A.<x,y> = TateAlgebra(R)
            sage: f = 3*x^2 + 5*x*y^2
            sage: g = 5*x^2*y + 3
            sage: I = A.ideal([f,g]); I
            Ideal (...0000000012*x*y^2 + ...00000000010*x^2, ...0000000012*x^2*y + ...00000000010)
             of Tate Algebra in x (val >= 0), y (val >= 0) over 3-adic Field with capped relative precision 10
            sage: I.saturate()
            Ideal (...0000000012*x*y^2 + ...00000000010*x^2, ...0000000012*x^2*y + ...00000000010)
             of Tate Algebra in x (val >= 0), y (val >= 0) over 3-adic Field with capped relative precision 10

            sage: I.saturate() == I
            True

        However, the result might be different over the ring of integers
        of a Tate algebra::

            sage: Ao = A.integer_ring()
            sage: Io = Ao.ideal([f,g])
            sage: Ios = Io.saturate(); Ios
            Ideal (...0000000001*x^2*y + ...1210121020 + O(3^10 * <x, y>),
                   ...0000000001*x*y^2 + ...1210121020*x^2 + O(3^10 * <x, y>),
                   ...000000001*x^3 + ...222222222*y + O(3^9 * <x, y>),
                   ...000000001*y^2 + ...210121020*x + O(3^9 * <x, y>))
             of Integer ring of the Tate Algebra in x (val >= 0), y (val >= 0) over 3-adic Field with capped relative precision 10

            sage: Io == Ios
            False
            sage: Ios.is_saturated()
            True

        TESTS::

            sage: Io < Ios
            True
            sage: 3*Ios < Io
            True

        """
        if self.ring().base_ring().is_field():
            return self
        gb = self.groebner_basis()
        gens = [ g.monic() for g in gb ]
        return self.ring().ideal(gens)



# Grobner bases computations
############################

# Buchberger algorithm

cdef _groebner_basis_buchberger(I, prec, bint integral):
    r"""
    Compute a Groebner basis of the Tate algebra ideal I using Buchberger's algorithm

    INPUT:

    - ``I`` - an ideal in a Tate series algebra

    - ``prec`` - the related precision at which the initial generators
      are truncated

    - ``integral`` -- a boolean; if ``True``, first compute a
      Grobner basis of the ideal generated by the same generators over
      the ring over the ring of integers

    NOTE::

    This function is not meant to be called directly, but through the
    ``groebner_basis`` method of Tate algebra ideals.

    EXAMPLES::

        sage: R = Zp(3, prec=10, print_mode="digits");
        sage: A.<x,y> = TateAlgebra(R)
        sage: f = 3*x^2 + 5*x*y^2
        sage: g = 5*x^2*y + 3
        sage: I = A.ideal([f,g]); I
        Ideal (...0000000012*x*y^2 + ...00000000010*x^2, ...0000000012*x^2*y + ...00000000010) of Tate Algebra in x (val >= 0), y (val >= 0) over 3-adic Field with capped relative precision 10
        sage: I.groebner_basis()  # indirect doctest
        [...000000001*x^3 + ...222222222*y + O(3^9 * <x, y>),
         ...0000000001*x^2*y + ...1210121020 + O(3^10 * <x, y>),
         ...000000001*y^2 + ...210121020*x + O(3^9 * <x, y>)]

    """
    cdef list gb, rgb, indices, ts, S = [ ]
    cdef int i, j, l
    cdef TateAlgebraTerm ti, tj, t
    cdef TateAlgebraElement f, g, r, s
    cdef bint reduce = True

    gb = [ ]
    l = 0
    for f in I.gens():
        if f == 0:
            continue
        g = f.add_bigoh(f.valuation() + prec)
        if g == 0:
            continue
        gb.append(g)
        l += 1
    indices = list(range(l))

    # We minimize the family of generators
    rgb = gb[:]
    i = 0
    while i < len(rgb):
        ti = (<TateAlgebraElement>rgb[i])._terms_c()[0]
        for j in range(len(rgb)):
            tj = (<TateAlgebraElement>rgb[j])._terms_c()[0]
            if j != i and tj._divides_c(ti, integral):
                del rgb[i]
                del indices[i]
                break
        else:
            i += 1

    # We compute the initial S-polynomials
    for i in range(l):
        ti = (<TateAlgebraElement>gb[i])._terms_c()[0]
        for j in range(i+1, l):
            tj = (<TateAlgebraElement>gb[j])._terms_c()[0]
            if not ti.is_coprime_with(tj):
                s = (<TateAlgebraElement>gb[i])._Spoly_c(<TateAlgebraElement>gb[j])
                if not s.is_zero():
                    t = s._terms_c()[0]
                    heappush(S, (t._valuation_c(), t._exponent, i, j, s))

    # Main loop of Buchberger algorithm
    # Loop invariant:
    # the S-polynomials of pairs of elements in rgb 
    # all reduce to zero modulo (rgb,S)
    while S:
        # We reduce the Grobner basis if needed
        if reduce:
            reduce = False
            for i in range(len(rgb)-1, -1, -1):
                g = rgb[i]
                rgb[i] = g._positive_lshift_c(1)
                _, rgb[i] = g._quo_rem_c(rgb, False, True, True)
                gb[indices[i]] = rgb[i]

        # We pop a new S-polynomial
        _, _, i, j, f = heappop(S)
        if i >= 0 and (gb[i] is None or gb[j] is None):
            continue
        _, r = f._quo_rem_c(rgb, False, True, integral)
        if r.is_zero():
            continue

        # We add it to our Grobner basis
        tj = r._terms_c()[0]
        j = len(gb)
        for i in range(j):
            g = gb[i]
            if g is None: continue
            ti = g._terms_c()[0]
            if not ti.is_coprime_with(tj):  # first Buchberger criterium
                s = g._Spoly_c(r)
                if not s.is_zero():
                    t = s._terms_c()[0]
                    heappush(S, (t._valuation_c(), t._exponent, i, j, s))
        gb.append(r)

        # We minimize the Grobner basis
        i = 0
        while i < len(rgb):
            ti = (<TateAlgebraElement>rgb[i])._terms_c()[0]
            if tj._divides_c(ti, integral):
                if indices[i] >= l:
                    heappush(S, (ti._valuation_c(), ti._exponent, -1, -1, rgb[i]))
                    gb[indices[i]] = None
                del rgb[i]
                del indices[i]
            else:
                i += 1
        rgb.append(r)
        indices.append(j)
        # and reduce it
        reduce = True

    base = I.ring().base_ring()
    if base.is_field():
        if integral:
            # We need to minimize and reduce the Groebner basis again
            i = 0
            while i < len(rgb):
                ti = (<TateAlgebraElement>rgb[i])._terms_c()[0]
                for j in range(len(rgb)):
                    tj = (<TateAlgebraElement>rgb[j])._terms_c()[0]
                    if j != i and tj._divides_c(ti, False):
                        del rgb[i]
                        break
                else:
                    rgb[i] = rgb[i].monic()
                    i += 1
            for i in range(len(rgb)):
                g = rgb[i]
                rgb[i] = g._positive_lshift_c(1)
                _, rgb[i] = g._quo_rem_c(rgb, False, True, True)
        else:
            rgb = [ g.monic() for g in rgb ]
    else:
        rgb = [ g * base(g.leading_coefficient().unit_part()).inverse_of_unit() for g in rgb ]

    rgb.sort(reverse=True)
    return rgb


# F5 algorithm

def Jpair(p1, p2):
    s1, v1 = p1  # we assume that s1 is not None
    s2, v2 = p2
    if v1 == 0 or v2 == 0:
        return
    sv1 = v1.leading_term()
    sv2 = v2.leading_term()
    t = sv1.lcm(sv2)
    t1 = t // sv1
    t2 = t // sv2
    su1 = t1*s1
    if s2 is None:
        return su1, t1*v1 
    su2 = t2*s2
    if su1 > su2:
        return su1, t1*v1
    elif su2 > su1:
        return su2, t2*v2

def regular_reduce(sgb, s, v, tail, verbose):
    res = v.parent()(0, v.precision_absolute())
    count = 0
    while v != 0:
        sv = v.leading_term()
        # We first check for top reduction
        for S,V in sgb:
            if V == 0: continue
            sV = V.leading_term()
            if sV.divides(sv):
                t = sv // sV
                if S is None or t*S < s:
                    v -= t*V
                    count += 1
                    if verbose > 3:
                        print("| regular reduction by (sign = %s, series = %s)" % (S,V))
                        print("| new series is: %s" % (res+v))
                    break
        else:  
            # no possible top-reduction
            if not tail:
                res = v
                break
            res += sv
            v -= sv
    if verbose > 1:
        print("| %s regular reductions done" % count)
    return res


def print_pair(p, verbose):
    if verbose > 3:
        return "(sign = %s, series = %s)" % p
    else:
        s, v = p
        return "(sign = %s, series = %s + ...)" % (s, v.leading_term())

def _groebner_basis_F5(I, prec, verbose):
    cdef TateAlgebraElement g
    cdef TateAlgebraTerm ti, tj

    term_one = I.ring().monoid_of_terms().one()
    gb = [ ]

    for f in I.gens():
        if verbose > 0:
            print("---")
            print("new generator: %s" % f)
        # Initial strong Grobner basis:
        # we add signatures
        sgb = [ (None, g) for g in gb if g != 0 ]
        # We compute initial J-pairs
        l = len(sgb)
        p = (term_one, f.add_bigoh(prec))
        Jpairs = [ ]
        for P in sgb:
            J = Jpair(p, P)
            if J is not None:
                heappush(Jpairs, J)
        sgb.append(p)

        # For the syzygy criterium
        gb0 = [ g.leading_term() for g in gb ]

        if verbose > 1:
            print("%s initial J-pairs" % len(Jpairs))
        if verbose > 2:
            for s,v in Jpairs:
                print("| sign = %s; series = %s" % (s,v))

        while Jpairs:
            s, v = heappop(Jpairs)
            sv = v.leading_term()

            if verbose == 2:
                print("pop one J-pair; %s remaining J-pairs" % len(Jpairs))
            if verbose > 2:
                print("current J-pair: " + print_pair((s,v), verbose))
                print("%s remaining J-pairs" % len(Jpairs))

            # The syzygy criterium
            syzygy = None
            for S in gb0:
                if S.divides(s):
                    syzygy = S
                    break
            if syzygy is not None:
                if verbose > 1:
                    print("| skip: sygyzy criterium; signature = %s" % syzygy)
                continue

            # We check if (s,v) is covered by 
            # the current strong Grobner basis
            cover = None
            for S, V in sgb:
                if S is not None and S.divides(s):
                    sV = V.leading_term()
                    if (s // S)*sV < sv:
                        cover = (S,V)
                        break
            if cover is not None:
                if verbose > 1:
                    print("| skip: cover by " + print_pair(cover, verbose))
                continue

            # We perform regular top-reduction
            v = regular_reduce(sgb, s, v, True, verbose)

            if v == 0:
                # We have a new element in (I0:f) whose signature
                # could be useful to strengthen the syzygy criterium
                #print ("| add signature for syzygy criterium: %s" % s)
                gb0.append(s)
            else:
                # We update the current strong Grobner basis
                # and the J-pairs accordingly
                p = (s,v)
                if verbose > 1:
                    print("| new element is SGB: " + print_pair(p, verbose))
                count = 0
                for P in sgb:
                    J = Jpair(p, P)
                    if J is not None:
                        count += 1
                        if verbose > 2:
                            print("| add J-pair: " + print_pair(J, verbose))
                        heappush(Jpairs, J)
                if verbose > 1:
                    print("| add %s J-pairs" % count)
                sgb.append(p)

        # We forget signatures
        gb = [ v.monic() for (s,v) in sgb ]
        if verbose > 1:
            print("%s elements in GB before minimization" % len(gb))
        if verbose > 3:
            for g in gb:
                print("| %s" % g)
        # we minimize the Grobner basis
        i = 0
        while i < len(gb):
            ti = (<TateAlgebraElement>gb[i])._terms_c()[0]
            for j in range(len(gb)):
                tj = (<TateAlgebraElement>gb[j])._terms_c()[0]
                if j != i and tj._divides_c(ti, False):
                    del gb[i]
                    break
            else:
                i += 1
        if verbose > 0:
             if verbose > 1:
                 s = " after minimization"
             else:
                 s = ""
             print("%s elements in GB%s" % (len(gb), s))
        if verbose > 3:
            for g in gb:
                print("| %s" % g)
        # and reduce it
        for i in range(len(gb)-1, -1, -1):
            g = gb[i]
            gb[i] = g._positive_lshift_c(1)
            _, gb[i] = g._quo_rem_c(gb, False, True, True)
        if verbose > 1:
            print("grobner basis reduced")
        if verbose > 0:
            for g in gb:
                print("| %s" % g)

    return gb


    
def _vopot_key(u,i,v):
    # This doesn't really need v
    return (u.valuation(),i,u)

def _regular_reduce_vopot(sgb,p,tail=True):
    s,i,v = p
    res = 0
    key = _vopot_key(s,i,v) # independent of v
    while v != 0:
        sv = v.leading_term()
        for S,I,V in sgb:
            if V == 0: continue
            sV = V.leading_term()
            if sV.divides(sv):
                t = sv // sV
                if _vopot_key(t*S,I,V) < key:
                    v -= t*V
                    print("| regular top-reduction by (sign = %s, series = %s)" % (S,V))
                    print("| new series is: %s" % v)
                    break # Or maybe not?
        if tail:
            res += v.leading_term()
            vv -= v.leading_term()
        else:
            res = v
            break
    return res

def _Jpair_vopot(p1,p2):
    u1,i1,v1 = p1
    u2,i2,v2 = p2
    if (v1 == 0 or v2 == 0) :
        return
    sv1 = v1.leading_term()
    sv2 = v2.leading_term()
    t = sv1.lcm()
    t1 = t//sv1
    t2 = t//sv2
    su1 = t1*u1
    su2 = t2*u2
    # We can probably save half the computations above in a lot of cases

    vu1 = _vopot_key(u1,i1,v1)
    vu2 = _vopot_key(u2,i2,v2)
    if vu1 < vu2:
        return su1,t1*v1
    elif vu2 > vu1:
        return su2,t2*v2
    else:
        return
    
def _groebner_basis_F5_vopot(I,prec):
    term_one = I.ring().monoid_of_terms().one()
    gb0 = []
    sgb = []

    F = I.gens()
    l = len(F)
    for i in range(l):
        sgb.append((term_one,i,F[i]))

    Jpairs = []
    for i in range(l):
        for j in range(l):
            J = _Jpair_vopot(sgb[i],sgb[j])
            if J is not None:
                Jpairs.append(J)

    while Jpairs:
        # This all can probably be made more efficient, for example by sorting
        # the list every time we add a pair, or by inserting the pairs at the
        # right position
        idx = min(range(len(Jpairs)), key=lambda i: _vopot_key(Jpairs[i]))
        s,i,v = Jpairs.pop(idx) 
                
        sv = v.leading_term()

        # TODO: syzygy criterion

        # TODO: F5 criterion maybe

        # TODO: cover criterion

        # Regular top and tail reduction
        v = _regular_reduce_vopot(sgb,(s,i,v))
        
        if v == 0:
            # New syzygy
            gb0.append(s)
        else:
            p = (s,i,v)
            
            # New J-pairs
            for P in sgb:
                J = _Jpair_vopot(p,P)
                if J is not None:
                    Jpairs.append(J)
            
            # New element in the basis
            sgb.append(p)

            # TODO New F5 syzygy
            ## Here we need to assign a signature which is known to be smaller
            ## than all the (*,i) but larger than all the (*,i-1). A good choice
            ## would be (1/p,i).
            ##
            ## Another possibility is to do nothing here and use the F5
            ## criterion as it was originally described, by looking up in the
            ## basis.

    gb = [v for (s,i,v) in sgb]

    return gb
