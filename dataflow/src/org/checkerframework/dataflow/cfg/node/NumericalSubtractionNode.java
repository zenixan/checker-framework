package org.checkerframework.dataflow.cfg.node;

import com.sun.source.tree.Tree;
import com.sun.source.tree.Tree.Kind;
import java.util.Collection;
import java.util.LinkedList;
import org.checkerframework.dataflow.util.HashCodeUtils;
import org.checkerframework.javacutil.InternalUtils;

/**
 * A node for the numerical subtraction:
 *
 * <pre>
 *   <em>expression</em> - <em>expression</em>
 * </pre>
 *
 * @author Stefan Heule
 * @author Charlie Garrett
 */
public class NumericalSubtractionNode extends Node {

    protected Tree tree;
    protected Node left;
    protected Node right;

    public NumericalSubtractionNode(Tree tree, Node left, Node right) {
        super(InternalUtils.typeOf(tree));
        assert tree.getKind() == Kind.MINUS;
        this.tree = tree;
        this.left = left;
        this.right = right;
    }

    public Node getLeftOperand() {
        return left;
    }

    public Node getRightOperand() {
        return right;
    }

    @Override
    public Tree getTree() {
        return tree;
    }

    @Override
    public <R, P> R accept(NodeVisitor<R, P> visitor, P p) {
        return visitor.visitNumericalSubtraction(this, p);
    }

    @Override
    public String toString() {
        return "(" + getLeftOperand() + " - " + getRightOperand() + ")";
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == null || !(obj instanceof NumericalSubtractionNode)) {
            return false;
        }
        NumericalSubtractionNode other = (NumericalSubtractionNode) obj;
        return getLeftOperand().equals(other.getLeftOperand())
                && getRightOperand().equals(other.getRightOperand());
    }

    @Override
    public int hashCode() {
        return HashCodeUtils.hash(getLeftOperand(), getRightOperand());
    }

    @Override
    public Collection<Node> getOperands() {
        LinkedList<Node> list = new LinkedList<Node>();
        list.add(getLeftOperand());
        list.add(getRightOperand());
        return list;
    }
}
